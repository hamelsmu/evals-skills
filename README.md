# Eval Skills for AI Coding Agents

Skills that guide AI coding agents to help you build LLM evaluations.

These skills complement the [AI Evals course](https://maven.com/parlance-labs/evals?promoCode=evals-info-url) by Hamel Husain and Shreya Shankar. If you're new to evals, see [questions.md](questions.md) for free resources on the fundamentals.

## New to Evals? Start Here

If you are new to evals or aren't a student in our course, start with the `eval-audit` skill. Give your coding agent these instructions:

> Install the eval skills plugin from https://github.com/hamelsmu/evals-skills, then run /evals-skills:eval-audit on my eval pipeline. Investigate each diagnostic area using a separate subagent in parallel, then synthesize the findings into a single report. Use other skills in the plugin as recommended by the audit.

The audit isn't a complete solution, but it will catch common problems we've seen in evals. It will also recommend other skills to use to fix the problems.

## Installation

In Claude Code, run these two commands:

```bash
# Step 1: Register the plugin repository
/plugin marketplace add hamelsmu/evals-skills

# Step 2: Install the plugin
/plugin install evals-skills@hamelsmu-evals-skills
```

To upgrade:

```bash
/plugin update evals-skills@hamelsmu-evals-skills
```

After installation, restart Claude Code. The skills will appear as `/evals-skills:<skill-name>`.

## Installation (npx skills)

If you use the open Skills CLI, install from this repo with:

```bash
npx skills add https://github.com/hamelsmu/evals-skills
```

Install one skill only:

```bash
npx skills add https://github.com/hamelsmu/evals-skills --skill eval-audit
```

Check for updates:

```bash
npx skills check
npx skills update
```

## Available Skills

| Skill | What it does |
|-------|-------------|
| eval-audit | Audit an eval pipeline and surface problems with prioritized severity |
| error-analysis | Guide the user through reading traces and categorizing failures |
| generate-synthetic-data | Create diverse synthetic test inputs using dimension-based tuple generation |
| write-judge-prompt | Design LLM-as-Judge evaluators for subjective quality criteria |
| validate-evaluator | Calibrate LLM judges against human labels using data splits, TPR/TNR, and bias correction |
| evaluate-rag | Evaluate retrieval and generation quality in RAG pipelines |
| build-review-interface | Build custom annotation interfaces for human trace review |

Invoke a skill with `/evals-skills:skill-name`, e.g., `/evals-skills:error-analysis`.

## Write Your Own Skills

These skills are a starting point. You'll get better results writing skills that encode your own workflows, domain knowledge, and constraints. Skills grounded in your own data will vastly outperform these generic skills. Start here, then iterate toward custom skills.

The [meta-skill](meta-skill.md) can help you ground custom skills. It works best alongside the context provided in the course.

## Beyond These Skills

These skills handle the parts of eval work that generalize across projects. Much of the process doesn't: production monitoring, CI/CD integration, data analysis, and much more. The [course](https://maven.com/parlance-labs/evals?promoCode=evals-info-url) covers all of it.
