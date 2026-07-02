---
name: decompose-judge-criteria
description: >
  Decide whether an evaluation criterion should be a single binary judge or a
  bank of atomic yes/no questions, then generate the questions and aggregate
  their verdicts into an interpretable score. Use when a judge emits mushy 1-N
  scores, sits on the fence, clusters at the extremes, or misses errors that are
  locally wrong but globally plausible; or when you have a criterion (or a raw
  task prompt) and want finer-grained, debuggable verdicts. Do NOT use when a
  code-based check suffices, or when the criterion is genuinely holistic and
  humans judge it by overall impression.
---

# Decompose Judge Criteria into Atomic Binary Questions

Turn one evaluation criterion (or a raw task prompt) into a bank of atomic yes/no questions, where "yes" means the criterion is satisfied, then aggregate the answers into a per-dimension fraction score.

## Overview

1. Decide decompose-vs-single for the criterion.
2. Summarize the task or criterion into an explicit list of requirements.
3. Decompose each requirement into atomic binary questions, each phrased so "yes" = satisfied, each with a short violation example.
4. Answer each question independently per output, then aggregate the verdicts into per-dimension and overall fraction scores.
5. Diagnose whether the decomposition is pulling its weight (yes-rate spread, inter-question correlation, coverage).

## Prerequisites

None required; this skill runs on a single criterion or a raw task prompt as input.

Optional upstream and downstream skills (do not block on these):

- `write-judge-prompt` defines one criterion's pass/fail boundary. Run it first if the criterion is not yet defined; run it afterward to wrap each generated question in a full judge prompt (definitions, few-shot examples, structured output).
- `validate-evaluator` calibrates the resulting judge against human labels (TPR/TNR). Run it after decomposition to confirm the aggregated score aligns with humans.

## When to Decompose

Decompose when the criterion is concrete and its failures attach to specific claims, entities, spans, or constraints. Signs you should decompose:

- The current judge returns a 1-N or Likert score that clusters at the extremes or sits mid-scale.
- A single verdict hides which part failed (a summary that reads fluently but is factually wrong still scores well).
- The criterion names several checkable sub-properties (entities correct, numbers correct, no fabrication).

Keep a single binary question when the criterion is already atomic (one checkable property), or when a code-based check (regex, schema, parser, execution) can decide it. Prefer code over an LLM whenever the property is objective.

Do NOT decompose a genuinely holistic criterion (see "When Not to Decompose").

## Step 1: Summarize into Requirements

State the task or criterion, then list the distinct requirements it implies. Each requirement is one evaluation criterion (a key fact to include, a constraint to obey, a property to preserve). When the criterion spans more than one facet, group related requirements under named dimensions (for example: consistency, coherence, fluency, relevance).

## Step 2: Decompose into Binary Questions

For each requirement, write one or more questions such that "yes" = requirement satisfied and "no" = a violation. Split any requirement that hides multiple sub-checks into separate questions. Attach a one-line violation example to each question so the negative case is unambiguous.

Rules:

- Phrase every question so "yes" always means satisfied. Do not mix polarity within a bank.
- One property per question. If a question needs the word "and", split it.
- Feed each question only what it needs to decide the property: the output plus the relevant context (source document, persona, schema), and nothing more.
- Pair each question with a concrete violation example.

Reconstructed meta-prompt (an original reconstruction of the two-step method; adapt freely):

```
You are designing an evaluation. You are given a TASK (a task prompt, or a
single quality criterion).

Step 1 - Requirements.
Restate the TASK as an explicit list of requirements. Each requirement is one
distinct thing a correct output must do. If the TASK spans multiple facets, tag
each requirement with a dimension name.

Step 2 - Questions.
For each requirement, write one or more binary yes/no questions such that "yes"
means the requirement is satisfied and "no" means it is violated. Split any
requirement that contains more than one checkable property into separate
questions. For each question, add a one-line example of an output that would be
answered "no".

Return JSON:
{
  "requirements": [{"id": "r1", "dimension": "...", "text": "..."}],
  "questions": [
    {"id": "q1", "requirement": "r1", "dimension": "...",
     "question": "Does ...? (yes = satisfied)",
     "violation_example": "..."}
  ]
}

TASK:
{task_or_criterion}
```

## Step 3: Score by Aggregation

Answer each question independently for a given output, producing a 0/1 verdict plus a short explanation. Then aggregate:

- Per-dimension score = fraction of "yes" answers among that dimension's questions.
- Overall score = fraction of "yes" answers across all questions.

Both lie in [0, 1]. Map to another interval [a, b] with `S' = S * (b - a) + a` only when reporting against a tool that expects that scale. Keep the raw fraction and the per-question verdicts as the primary output, since a failing question tells the reviewer exactly what broke.

Aggregate verdicts (save as `aggregate.py`, run with `uv run aggregate.py`):

```python
# /// script
# requires-python = ">=3.10"
# ///
# aggregate.py: turn per-question verdicts into interpretable scores.
from collections import defaultdict


def scores(verdicts, scale=(0.0, 1.0)):
    """verdicts: list of (dimension, 0|1). Returns (per_dimension, overall)."""
    by_dim = defaultdict(list)
    for dim, verdict in verdicts:
        by_dim[dim].append(verdict)
    a, b = scale
    rescale = lambda frac: frac * (b - a) + a
    per_dim = {d: rescale(sum(vs) / len(vs)) for d, vs in by_dim.items()}
    overall = rescale(sum(v for _, v in verdicts) / len(verdicts))
    return per_dim, overall


if __name__ == "__main__":
    demo = [("consistency", 0), ("consistency", 1), ("consistency", 1),
            ("fluency", 1), ("fluency", 1)]
    print(scores(demo, scale=(1, 5)))
```

## Diagnose Whether Decomposition Helped

Run the question bank over a labeled sample, then inspect three properties to tell whether the bank adds signal or just noise:

- **Yes-rate spread.** Compute each question's yes-rate across outputs. A healthy bank spans a range of difficulties (some questions rarely fail, some often). If every question has a near-identical yes-rate, they are redundant.
- **Inter-question correlation.** Compute pairwise correlation (phi coefficient for binary answers) within a dimension. Low off-diagonal correlation means the questions capture distinct aspects, which is where aggregation reduces variance. A block of highly correlated questions is one question wearing several hats.
- **Pairwise coverage.** Look for pairs that are nearly uncorrelated but have different yes-rates; those catch disjoint failure modes (for example, a spelling check and a punctuation check). Drop questions that only duplicate existing coverage.

Use these to prune redundant questions and to flag dimensions where decomposition is not buying discrimination.

## When Not to Decompose

Some criteria are genuinely holistic: humans judge them by overall impression, with soft tolerance for missing minor details (for example, relevance, "did this capture the gist?"). Over-decomposing these produces an evaluator that demands exhaustive coverage and rates almost everything as deficient, which pushes its scores systematically below human scores and destroys rank correlation.

Worked cautionary case (from the source paper): decomposing "relevance" into strict per-item checks ("includes every key actor", "every motivation", "every background event", with a per-miss penalty) made the judge far stricter than human annotators; measured alignment fell (Spearman rho from about 0.505 to about 0.357). The fix is to keep holistic criteria as a small number of tolerant questions (or a single one), and to reserve fine-grained decomposition for criteria with concrete, enumerable failure modes such as factual consistency.

Heuristic: if you cannot phrase a question whose "no" points at a specific, agreed-upon defect, that facet is probably holistic; do not split it further.

## Future Extension (out of scope here)

The source method also defines a disagreement-driven loop that rewrites the judge (or generation) prompt from question-level failures. That optimization loop is not part of this skill; consider it only after the question bank is validated with `validate-evaluator`.

## Anti-Patterns

- Decomposing a holistic criterion into strict atomic checks, producing an evaluator harsher than humans.
- Mixing question polarity so "yes" sometimes means good and sometimes means bad.
- Writing compound questions ("Is it fluent and accurate?") instead of one property per question.
- Shipping a question bank without checking yes-rate spread and inter-question correlation for redundancy.
- Using an LLM question where a code-based check (regex, schema, parser, execution) is exact.
- Reporting only the aggregate fraction and discarding the per-question verdicts that make a failure actionable.
- Treating the aggregate as ground truth without calibrating against human labels (`validate-evaluator`).

## Attribution

Method: BinEval, "Ask, Don't Judge: Binary Questions for Interpretable LLM Evaluation and Self-Improvement", Cho et al., Capital One (arXiv:2606.27226; 2nd Workshop on Compositional Learning, ICML 2026). Workshop preprint, not archival peer review.

Lineage: UniEval (Zhong et al., 2022; evaluation as Boolean question answering) and FActScore (Min et al., 2023; decompose-then-verify). Those decompose generated content; BinEval decomposes the evaluation criteria themselves, which is the idea this skill applies.

The meta-prompt above is an original reconstruction of the paper's described two-step procedure, not copied text.
