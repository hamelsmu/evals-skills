---
name: evaluate-rag
description: >
  Guides evaluation of RAG pipeline retrieval and generation quality.
  Use when evaluating a retrieval-augmented generation system, measuring retrieval quality,
  assessing generation faithfulness or relevance, generating synthetic QA pairs for retrieval
  testing, or optimizing chunking strategies.
---

# Evaluate RAG

## Overview

1. Do error analysis on end-to-end traces first. Determine whether failures come from retrieval, generation, or both.
2. Build a retrieval evaluation dataset: queries paired with relevant document chunks.
3. Measure retrieval quality with Recall@k (most important for first-pass retrieval).
4. Evaluate generation separately: faithfulness (grounded in context?) and relevance (answers the query?).
5. If retrieval is the bottleneck, optimize chunking via grid search before tuning generation.

## Prerequisites

Complete error analysis on RAG pipeline traces before selecting metrics. Inspect what was retrieved vs. what the model needed. Determine whether the problem is retrieval, generation, or both. Fix retrieval first.

## Core Instructions

### Evaluate Retrieval and Generation Separately

Measure each component independently. Use the appropriate metric for each retrieval stage:

- **First-pass retrieval:** Optimize for Recall@k. Include all relevant documents, even at the cost of noise.
- **Reranking:** Optimize for Precision@k, MRR, or NDCG@k. Rank the most relevant documents first.

### Building a Retrieval Evaluation Dataset

You need queries paired with ground-truth relevant document chunks.

**Manual curation (highest quality):** Write realistic questions and map each to the exact chunk(s) containing the answer.

**Synthetic QA generation (scalable):** For each document chunk, prompt an LLM to extract a fact and generate a question answerable only from that fact.

Synthetic QA prompt template:

```
Given a chunk of text, extract a specific, self-contained fact from it.
Then write a question that is directly and unambiguously answered
by that fact alone.

Return output in JSON format:
{ "fact": "...", "question": "..." }

Chunk: "{text_chunk}"
```

**Adversarial question generation:** Create harder queries that resemble content in multiple chunks but are only answered by one.

Process:
1. Select target chunk A containing a clear fact.
2. Find similar chunks B, C using embedding search (chunks that share terminology but lack the answer).
3. Prompt the LLM to write a question using terminology from B and C that only chunk A answers.

Example:
- Chunk A: "In April 2020, the company reported a 17% drop in quarterly revenue, its largest decline since 2008."
- Chunk B: "The company experienced significant losses in 2008 during the financial crisis."
- Generated question: "When did the company experience its largest revenue decline since the 2008 financial crisis?"

Only chunk A contains the answer. Chunk B is a plausible distractor.

**Filtering synthetic questions:** Rate synthetic queries for realism using few-shot LLM scoring. Keep only those rated realistic (4-5 on a 1-5 scale). Likert scoring is appropriate here, since the goal is fuzzy ranking for dataset curation, not measuring failure rates.

### Retrieval Metrics

**Recall@k:** Fraction of relevant documents found in the top k results.

```
Recall@k = (relevant docs in top k) / (total relevant docs for query)
```

Prioritize recall for first-pass retrieval. LLMs can ignore irrelevant content but cannot generate from missing content.

**Precision@k:** Fraction of top k results that are relevant.

```
Precision@k = (relevant docs in top k) / k
```

Use for reranking evaluation.

**Mean Reciprocal Rank (MRR):** How early the first relevant document appears.

```
MRR = (1/N) * sum(1/rank_of_first_relevant_doc)
```

Best for single-fact lookups where only one key chunk is needed.

**NDCG@k (Normalized Discounted Cumulative Gain):** For graded relevance where documents have varying utility. Rewards placing more relevant items higher.

```
DCG@k  = sum over i=1..k of: rel_i / log2(i+1)
IDCG@k = DCG@k with documents sorted by decreasing relevance
NDCG@k = DCG@k / IDCG@k
```

Caveat: Optimal ranking of weakly relevant documents can outscore a highly relevant document ranked lower. Supplement with Recall@k.

**Choosing k:** k varies by query type. A factual lookup uses k=1-2. A synthesis query ("summarize market trends") uses k=5-10.

#### Metric Selection

| Query Type | Primary Metric |
|---|---|
| Single-fact lookups | MRR |
| Broad coverage needed | Recall@k |
| Ranked quality matters | NDCG@k or Precision@k |
| Multi-hop reasoning | Two-hop Recall@k |

### Evaluating and Optimizing Chunking

Treat chunking as a tunable hyperparameter. Even with the same retriever, metrics vary based on chunking alone.

**Grid search for fixed-size chunking:** Test combinations of chunk size and overlap. Re-index the corpus for each configuration. Measure retrieval metrics on your evaluation dataset.

Example search grid:

| Chunk size | Overlap | Recall@5 | NDCG@5 |
|-----------|---------|----------|--------|
| 128 tokens | 0 | 0.82 | 0.69 |
| 128 tokens | 64 | 0.88 | 0.75 |
| 256 tokens | 0 | 0.86 | 0.74 |
| 256 tokens | 128 | 0.89 | 0.77 |
| 512 tokens | 0 | 0.80 | 0.72 |
| 512 tokens | 256 | 0.83 | 0.74 |

**Content-aware chunking:** When fixed-size chunks split related information:
- Use natural document boundaries (sections, paragraphs, steps).
- Augment chunks with context: prepend document title and section headings to each chunk before embedding.

### Evaluating Generation Quality

After confirming retrieval works, evaluate what the LLM does with the retrieved context along two dimensions:

**Answer faithfulness:** Does the output accurately reflect the retrieved context? Check for:
- **Hallucinations:** Information absent from source documents. In RAG, even correct facts from the LLM's own knowledge count as hallucinations.
- **Omissions:** Relevant information from the context ignored in the output.
- **Misinterpretations:** Context information represented inaccurately.

**Answer relevance:** Does the output address the original query? An answer can be faithful to the context but fail to answer what the user asked.

Use error analysis to discover specific manifestations in your pipeline. Identify what kind of information gets hallucinated and which constraints get omitted.

#### Diagnosing Failures by Metric Pattern

| Context Relevance | Faithfulness | Answer Relevance | Diagnosis |
|---|---|---|---|
| High | High | Low | Generator attended to wrong section of a correct document |
| High | Low | -- | Hallucination or misinterpretation of retrieved content |
| Low | -- | -- | Retrieval problem. Fix chunking, embeddings, or query preprocessing |

### Multi-Hop Retrieval Evaluation

For queries requiring information from multiple chunks:

**Two-hop Recall@k:** Fraction of 2-hop queries where both ground-truth chunks appear in the top k results.

```
TwoHopRecall@k = (1/N) * sum(1 if {Chunk1, Chunk2} ⊆ top_k_results)
```

Diagnose failures by classifying: hop 1 miss, hop 2 miss, or rank-out-of-top-k.

## Anti-Patterns

- Using a single end-to-end correctness metric without separating retrieval and generation measurement.
- Jumping directly to metrics without reading traces first.
- Overfitting to synthetic evaluation data. Validate against real user queries regularly.
- Using similarity metrics (ROUGE, BERTScore, cosine similarity) as primary generation evaluation. Use binary evaluators driven by error analysis.
- Evaluating generation without checking context grounding.
