---
name: validate-evaluator
description: >
  Calibrate an LLM judge against human labels using data splits, TPR/TNR, and
  bias correction. Use after writing a judge prompt (write-judge-prompt) when you
  need to verify alignment before trusting its outputs. Do NOT use for code-based
  evaluators (those are deterministic; test with standard unit tests).
---

# Validate Evaluator

Calibrate an LLM judge against human judgment.

## Overview

1. Split human-labeled data into train (10-20%), dev (40-45%), test (40-45%)
2. Run judge on dev set and measure TPR/TNR
3. Iterate on the judge until TPR and TNR > 90% on dev set
4. Run once on held-out test set for final TPR/TNR
5. Apply bias correction formula to production data

## Prerequisites

- A built LLM judge prompt (from write-judge-prompt)
- Human-labeled data: ~100 traces with binary Pass/Fail labels per failure mode
  - Aim for ~50 Pass and ~50 Fail (balanced, even if real distribution is skewed)
  - Labels must come from a domain expert, not outsourced annotators
- Candidate few-shot examples from your labeled data

## Core Instructions

### Step 1: Create Data Splits

Split human-labeled data into three disjoint sets:

| Split | Size | Purpose | Rules |
|-------|------|---------|-------|
| **Training** | 10-20% (~10-20 examples) | Source of few-shot examples for the judge prompt | Only clear-cut Pass and Fail cases. Used directly in the prompt. |
| **Dev** | 40-45% (~40-45 examples) | Iterative evaluator refinement | Never include in the prompt. Evaluate against repeatedly. |
| **Test** | 40-45% (~40-45 examples) | Final unbiased accuracy measurement | Do NOT look at during development. Used once at the end. |

Target: 30-50 examples of each class (Pass and Fail) across dev and test combined. Use balanced splits even if real-world prevalence is skewed — you need enough Fail examples to measure TNR reliably.

```python
from sklearn.model_selection import train_test_split

# First split: separate test set
train_dev, test = train_test_split(
    labeled_data, test_size=0.4, stratify=labeled_data['label'], random_state=42
)
# Second split: separate training examples from dev set
train, dev = train_test_split(
    train_dev, test_size=0.75, stratify=train_dev['label'], random_state=42
)
# Result: ~15% train, ~45% dev, ~40% test
```

### Step 2: Run Evaluator on Dev Set

Run the judge on every example in the dev set. Compare predictions to human labels.

### Step 3: Measure TPR and TNR

**TPR (True Positive Rate):** When a human says Pass, how often does the judge also say Pass?

```
TPR = (judge says Pass AND human says Pass) / (human says Pass)
```

**TNR (True Negative Rate):** When a human says Fail, how often does the judge also say Fail?

```
TNR = (judge says Fail AND human says Fail) / (human says Fail)
```

```python
from sklearn.metrics import confusion_matrix

tn, fp, fn, tp = confusion_matrix(human_labels, evaluator_labels,
                                   labels=['Fail', 'Pass']).ravel()
tpr = tp / (tp + fn)
tnr = tn / (tn + fp)
```

Use TPR/TNR, not Precision/Recall or raw accuracy. These two metrics directly map to the bias correction formula. Use Cohen's Kappa only for measuring agreement between two human annotators, not for judge-vs-ground-truth.

### Step 4: Inspect Disagreements

Examine every case where the judge disagrees with human labels:

| Disagreement Type | Judge | Human | Fix |
|-------------------|-------|-------|-----|
| **False Pass** | Pass | Fail | Judge is too lenient. Strengthen Fail definitions or add edge-case examples. |
| **False Fail** | Fail | Pass | Judge is too strict. Clarify Pass definitions or adjust examples. |

For each disagreement, determine whether to:
- Clarify wording in the judge prompt
- Swap or add few-shot examples from the training set
- Add explicit rules for the edge case
- Split the criterion into more specific sub-checks

### Step 5: Iterate

Refine the judge prompt and re-run on the dev set. Repeat until TPR and TNR stabilize.

**Stopping criteria:**
- **Target:** TPR > 90% AND TNR > 90%
- **Minimum acceptable:** TPR > 80% AND TNR > 80%

**If alignment stalls:**

| Problem | Solution |
|---------|---------|
| TPR and TNR both low | Use a more capable LLM for the judge |
| One metric low, one acceptable | Inspect disagreements for the low metric specifically |
| Both plateau below target | Decompose the criterion into smaller, more atomic checks |
| Consistently wrong on certain input types | Add targeted few-shot examples from training set |
| Labels themselves seem inconsistent | Re-examine human labels; the rubric may need refinement |

### Step 6: Final Measurement on Test Set

Run the judge **exactly once** on the held-out test set. Record final TPR and TNR.

Do not iterate after seeing test set results. Go back to step 4 with new dev data if needed.

### Step 7 (Optional): Estimate True Success Rate (Rogan-Gladen Correction)

Raw judge scores on unlabeled production data are biased. If you need an accurate aggregate pass rate, correct for known judge errors:

```
theta_hat = (p_obs + TNR - 1) / (TPR + TNR - 1)
```

Where:
- `p_obs` = fraction of unlabeled traces the judge scored as Pass
- `TPR`, `TNR` = from test set measurement
- `theta_hat` = corrected estimate of true success rate

Clip to [0, 1]. Invalid when TPR + TNR - 1 is near 0 (judge is no better than random).

**Example:**
- Judge TPR = 0.92, TNR = 0.88
- 500 production traces: 400 scored Pass -> p_obs = 0.80
- theta_hat = (0.80 + 0.88 - 1) / (0.92 + 0.88 - 1) = 0.68 / 0.80 = **0.85**
- True success rate is ~85%, not the raw 80%

### Step 8: Confidence Interval

Compute a bootstrap confidence interval. A point estimate alone is not enough.

```python
import numpy as np

def bootstrap_ci(human_labels, eval_labels, p_obs, n_bootstrap=2000):
    """Bootstrap 95% CI for corrected success rate."""
    n = len(human_labels)
    estimates = []
    for _ in range(n_bootstrap):
        idx = np.random.choice(n, size=n, replace=True)
        h = np.array(human_labels)[idx]
        e = np.array(eval_labels)[idx]

        tp = ((h == 'Pass') & (e == 'Pass')).sum()
        fn = ((h == 'Pass') & (e == 'Fail')).sum()
        tn = ((h == 'Fail') & (e == 'Fail')).sum()
        fp = ((h == 'Fail') & (e == 'Pass')).sum()

        tpr_b = tp / (tp + fn) if (tp + fn) > 0 else 0
        tnr_b = tn / (tn + fp) if (tn + fp) > 0 else 0
        denom = tpr_b + tnr_b - 1

        if abs(denom) < 1e-6:
            continue
        theta = (p_obs + tnr_b - 1) / denom
        estimates.append(np.clip(theta, 0, 1))

    return np.percentile(estimates, 2.5), np.percentile(estimates, 97.5)

lower, upper = bootstrap_ci(test_human, test_eval, p_obs=0.80)
print(f"95% CI: [{lower:.2f}, {upper:.2f}]")
```

Or use `judgy` (`pip install judgy`):

```python
from judgy import estimate_success_rate

result = estimate_success_rate(
    human_labels=test_human_labels,
    evaluator_labels=test_eval_labels,
    unlabeled_labels=prod_eval_labels
)
print(f"Corrected rate: {result.estimate:.2f}")
print(f"95% CI: [{result.ci_lower:.2f}, {result.ci_upper:.2f}]")
```

## Practical Guidance

- **Pin exact model versions** for LLM judges (e.g., `gpt-4o-2024-05-13`, not `gpt-4o`). Providers update models without notice, causing silent drift.
- **Re-validate** after changing the judge prompt, switching models, or when production confidence intervals widen unexpectedly.
- Use ~100 labeled examples (50 Pass, 50 Fail). Below 60, confidence intervals become wide.
- **One trusted domain expert** is the most efficient labeling path. If not feasible, have two annotators label 20-50 traces independently and resolve disagreements before proceeding.
- **Improving TPR narrows the confidence interval more than improving TNR.** The correction formula divides by TPR, so low TPR amplifies estimation errors into wide CIs.

## Anti-Patterns

- **Assuming judges "just work" without validation.** A judge may consistently miss failures or flag passing traces.
- **Using raw accuracy or percent agreement.** Use TPR and TNR. With class imbalance, raw accuracy is misleading.
- **Dev/test examples as few-shot examples.** This is data leakage.
- **Reporting dev set performance as final accuracy.** Dev numbers are optimistic. The test set gives the unbiased estimate.
- **Raw judge scores without bias correction.** If you report an aggregate pass rate, apply the Rogan-Gladen formula (Step 7).
- **Point estimates without confidence intervals.** A corrected rate of 85% could easily be 78-92% with small test sets. Report the range so stakeholders know how much to trust the number.
