---
name: generate-synthetic-data
description: >
  Create diverse synthetic test inputs for LLM pipeline evaluation using
  dimension-based tuple generation. Use when bootstrapping an eval dataset,
  when real user data is sparse, or when stress-testing specific failure
  hypotheses. Do NOT use when you already have 100+ representative real
  traces (use stratified sampling instead), or when the task is collecting
  production logs.
---

# Generate Synthetic Data

Generate diverse, realistic test inputs that cover the failure space of an LLM pipeline.

## Prerequisites

Before generating synthetic data, identify where the pipeline is likely to fail. Ask the user about known failure-prone areas, review existing user feedback, or form hypotheses from available traces. Dimensions (Step 1) must target anticipated failures, not arbitrary variation.

## Core Process

### Step 1: Define Dimensions

Dimensions are axes of variation specific to your application. Choose dimensions based on where you expect failures.

```
Dimension 1: [Name] — [What it captures]
  Values: [value_a, value_b, value_c, ...]

Dimension 2: [Name] — [What it captures]
  Values: [value_a, value_b, value_c, ...]

Dimension 3: [Name] — [What it captures]
  Values: [value_a, value_b, value_c, ...]
```

Example for a real estate assistant:

```
Feature: what task the user wants
  Values: [property search, scheduling, email drafting]

Client Persona: who the user serves
  Values: [first-time buyer, investor, luxury buyer]

Scenario Type: query clarity
  Values: [well-specified, ambiguous, out-of-scope]
```

Start with 3 dimensions. Add more only if initial traces reveal failure patterns along new axes.

### Step 2: Draft 20 Tuples with the User

A tuple is one combination of dimension values defining a specific test case. Present 20 draft tuples to the user and iterate until they confirm the tuples reflect realistic scenarios. The user's domain knowledge is essential here — they know which combinations actually occur and which are unrealistic.

```
(Feature: Property Search, Persona: Investor, Scenario: Ambiguous)
(Feature: Scheduling, Persona: First-time Buyer, Scenario: Well-specified)
(Feature: Email Drafting, Persona: Luxury Buyer, Scenario: Out-of-scope)
```

### Step 3: Generate More Tuples with an LLM

```
Generate 10 random combinations of ({dim1}, {dim2}, {dim3})
for a {your application description}.

The dimensions are:
{dim1}: {description}. Possible values: {values}
{dim2}: {description}. Possible values: {values}
{dim3}: {description}. Possible values: {values}

Output each tuple in the format: ({dim1}, {dim2}, {dim3})
Avoid duplicates. Vary values across dimensions.
```

### Step 4: Convert Each Tuple to a Natural Language Query

Use a separate prompt for this step. Single-step generation (tuples + queries together) produces repetitive phrasing.

```
We are generating synthetic user queries for a {your application}.
{Brief description of what it does.}

Given:
{dim1}: {value}
{dim2}: {value}
{dim3}: {value}

Write a realistic query that a user might enter. The query should
reflect the specified persona and scenario characteristics.

Example: "{one of your hand-written examples}"

Now generate a new query.
```

### Step 5: Filter for Quality

Review generated queries. Discard and regenerate when:
- Phrasing is awkward or unrealistic
- Content doesn't match the tuple's intent
- Queries are too similar to each other

Optional: use an LLM to rate realism on a 1-5 scale, discard below 3.

### Step 6: Run Queries Through the Pipeline

Execute all queries through the full LLM pipeline. Capture complete traces: input, all intermediate steps, tool calls, retrieved docs, final output.

**Target: ~100 high-quality, diverse traces.** This is a rough heuristic for reaching saturation (where new traces stop revealing new failure categories). The number depends on system complexity.

## Sampling Real User Data

When you have real queries available, don't sample randomly. Use stratified sampling:

1. **Identify high-variance dimensions** — read through queries and find ways they differ (length, topic, complexity, presence of constraints).
2. **Assign labels** — for small sets, with the user; for large sets, use K-means clustering on query embeddings.
3. **Sample from each group** — ensures coverage across query types, not just the most common ones.

When both real and synthetic data are available, use synthetic data to fill gaps in underrepresented query types.

## Anti-Patterns

- **Unstructured generation.** Prompting "give me test queries" without the dimension/tuple structure produces generic, repetitive, happy-path examples.
- **Single-step generation.** Generating tuples and queries in one prompt produces less diverse results than the two-step separation.
- **Arbitrary dimensions.** Dimensions that don't target failure-prone regions waste test budget.
- **Skipping user review of tuples.** Without the user validating tuples first, you can't judge whether LLM-generated tuples are realistic.
- **Synthetic data when no one can judge realism.** If no one can judge whether a synthetic trace is realistic, use real data instead.
- **Synthetic data for complex domain-specific content** (legal filings, medical records) where LLMs miss structural nuance.
- **Synthetic data for low-resource languages or dialects** where LLM-generated samples are unrealistic.
