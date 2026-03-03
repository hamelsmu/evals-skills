---
name: write-judge-prompt
description: >
  Design LLM-as-Judge evaluators for subjective criteria that code-based checks
  cannot handle. Use when a failure mode requires interpretation (tone,
  faithfulness, relevance, completeness). Do NOT use when the failure mode can be
  checked with code (regex, schema validation, execution tests). Do NOT use when
  you need to validate or calibrate the judge — use validate-evaluator instead.
---

# Write LLM-as-Judge Prompt

Design a binary Pass/Fail LLM-as-Judge evaluator for one specific failure mode. Each judge checks exactly one thing.

## Prerequisites

- Error analysis is complete. The failure mode is identified.
- You have human-labeled traces for this failure mode (at least 20 Pass and 20 Fail examples).
- A code-based evaluator cannot check this failure mode. Exhaust code-based options before reaching for a judge — many failure modes that seem subjective reduce to keyword checks, regex, or API calls when you understand the domain. Example: detecting whether an AI interviewing coach suggests "general" questions (asking about typical behavior instead of a specific past event) seems to require semantic understanding, but in practice a keyword check for words like "usually," "typical," and "normally" could work quite well.

## The Four Components

Every judge prompt requires exactly four components:

### 1. Task and Evaluation Criterion

State what the judge evaluates. One failure mode per judge.

```
You are an evaluator assessing whether a real estate assistant's email
uses the appropriate tone for the client's persona.
```

Not: "Evaluate whether the email is good" or "Rate the email quality from 1-5."

### 2. Pass/Fail Definitions

Outcomes are strictly binary: Pass or Fail. No Likert scales, no letter grades, no partial credit. Define exactly what constitutes Pass and Fail. These definitions come from your error analysis failure mode descriptions.

```
## Definitions

PASS: The email matches the expected communication style for the client persona:
- Luxury Buyers: formal language, emphasis on exclusive features, premium
  market positioning, no casual slang
- First-Time Homebuyers: warm and encouraging tone, educational explanations,
  avoids jargon, patient and supportive
- Investors: data-driven language, ROI-focused, market analytics, concise
  and professional

FAIL: The email uses a tone mismatched to the client persona. Examples:
- Using casual slang ("hey, check out this pad!") for a luxury buyer
- Using heavy financial jargon for a first-time homebuyer
- Using overly emotional language for an investor
```

### 3. Few-Shot Examples

Include labeled Pass and Fail examples from your human-labeled data.

```
## Examples

### Example 1: PASS
Client Persona: Luxury Buyer
Email: "Dear Mr. Harrington, I am pleased to present an exclusive listing
at 1200 Pacific Heights Drive. This distinguished property features..."
Critique: The email opens with a formal salutation and uses language
consistent with luxury positioning — "exclusive listing," "distinguished
property." No casual slang or informal phrasing. The tone matches the
luxury buyer persona throughout.
Result: Pass

### Example 2: FAIL
Client Persona: Luxury Buyer
Email: "Hey! Just found this awesome place you might like. It's got a
pool and stuff, super cool neighborhood..."
Critique: The greeting "Hey!" is informal. Phrases like "awesome place,"
"got a pool and stuff," and "super cool" are casual slang inappropriate
for a luxury buyer. The email reads like a text message, not a
professional communication for a high-end client.
Result: Fail

### Example 3: PASS (borderline)
Client Persona: First-Time Homebuyer
Email: "Hi Sarah, I found a property that might be a great fit for your
first home. The neighborhood has good schools nearby, and the monthly
payment would be similar to what you're currently paying in rent..."
Critique: The greeting is warm but not overly casual. The email explains
the property in relatable terms — comparing mortgage to rent, mentioning
schools — which is educational without being condescending. It avoids
jargon like "amortization" or "LTV ratio." While not deeply technical,
this matches the supportive tone expected for a first-time buyer.
Result: Pass
```

**Rules for selecting examples:**
- Include at least one clear Pass, one clear Fail, and one borderline case. Borderline examples are the most valuable — they teach nuance.
- Draw examples from the training split (10-20% of labeled data set aside for this purpose).
- Any example used in the judge prompt must be excluded from dev and test sets. Using dev/test examples is data leakage.
- 2-4 examples is typical. Performance plateaus after 4-8.

### 4. Structured Output Format

Enforce structured output using your LLM provider's schema enforcement (e.g., `response_format` in OpenAI, tool definitions in Anthropic) or a library like Instructor or Outlines. If the provider doesn't support schema enforcement, specify the JSON schema in the prompt.

The output must include a critique before the verdict. Placing the critique first forces the judge to articulate its assessment before committing to a decision.

```json
{
  "critique": "string — detailed assessment of the output against the criterion",
  "result": "Pass or Fail"
}
```

Critiques must be detailed, not terse. A good critique explains what specifically was correct or incorrect and references concrete evidence from the output. The critiques in your few-shot examples set the bar for the level of detail the judge will produce.

## Choosing What to Pass to the Judge

Feed only what the judge needs for an accurate decision:

| Failure Mode | What the Judge Needs |
|-------------|---------------------|
| Tone mismatch | Client persona + generated email |
| Answer faithfulness | Retrieved context + generated answer |
| SQL correctness | User query + generated SQL + schema |
| Instruction following | System prompt rules + generated response |
| Tool call justification | Conversation history + tool call + tool result |

For long documents, feed only the relevant snippet, not the entire document.

## Model Selection

Start with the most capable model available. The same model used for the main task works as judge (the judge performs a different, narrower task). Optimize for cost later once alignment is confirmed.

## Anti-Patterns

- **Vague criteria like "is this helpful?"** Target a specific, observable failure mode from error analysis.
- **Holistic judge for the entire trace.** A single judge covering multiple dimensions produces unactionable verdicts.
- **No few-shot examples.** Without examples, the model won't know what counts as a failure in your application.
- **Dev/test examples used as few-shot.** This is data leakage. Use only the training split.
- **Likert scales (1-5, letter grades, etc.).** Binary pass/fail only. Likert scales produce scores that sound precise but can't be calibrated: annotators disagree on the difference between a 3 and a 4, and the judge inherits that noise. Binary forces you to define a clear decision boundary upfront, which makes inter-annotator agreement measurable and the judge's errors actionable. If you need to capture severity, use multiple binary judges (e.g., "factually wrong" and "dangerously wrong") rather than one ordinal scale.
- **Skipping validation.** Measure alignment with human labels using validate-evaluator before trusting the judge.
- **Judges for specification failures without fixing the prompt first.** If the prompt never asked for the behavior, add the instruction before building an evaluator. For critical requirements, a judge can still serve as a regression guard.
