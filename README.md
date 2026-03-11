# Eval Skills for AI Coding Agents

Skills that guide AI coding agents to help you build LLM evaluations.

These skills guard against common mistakes I've seen helping 50+ companies and teaching students in our [AI Evals course](https://maven.com/parlance-labs/evals?promoCode=evals-info-url). If you're new to evals, see [questions.md](questions.md) for free resources on the fundamentals.

## New to Evals? Start Here

If you are new to evals, start with the `eval-audit` skill. Give your coding agent these instructions:

> Install the eval skills plugin from https://github.com/hamelsmu/evals-skills, then run /evals-skills:eval-audit on my eval pipeline. Investigate each diagnostic area using a separate subagent in parallel, then synthesize the findings into a single report. Use other skills in the plugin as recommended by the audit.

> In Codex, open this repository and use `$eval-audit` on my eval pipeline. Investigate each diagnostic area using a separate subagent in parallel, then synthesize the findings into a single report. Use other skills from this repository as recommended by the audit.

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

## Installation (Codex)

Codex discovers repository skills from `.agents/skills` and personal skills from `~/.codex/skills`.

Use these skills directly from a clone of this repository:

```bash
git clone https://github.com/hamelsmu/evals-skills.git
cd evals-skills
codex
```

From the Codex session, run `/skills` to confirm the skills are in scope, or invoke one explicitly with `$skill-name`, for example `$eval-audit`.

To make one skill available in every Codex session, symlink or copy it into `~/.codex/skills`:

```bash
mkdir -p ~/.codex/skills
ln -s /path/to/evals-skills/.agents/skills/eval-audit ~/.codex/skills/eval-audit
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

Invoke a skill in Claude Code with `/evals-skills:skill-name`, e.g., `/evals-skills:error-analysis`.
In Codex, run `/skills` or invoke a skill explicitly with `$skill-name`, e.g., `$error-analysis`.

## Write Your Own Skills

These skills are a starting point and only encode common mistakes that generalize across projects. Skills grounded in your stack, your domain, and your data will outperform them. Start here, then write your own.

The [meta-skill](meta-skill.md) can help you ground custom skills. 

## Beyond These Skills

These skills handle the parts of eval work that generalize across projects. Much of the process doesn't: production monitoring, CI/CD integration, data analysis, and much more. The [course](https://maven.com/parlance-labs/evals?promoCode=evals-info-url) covers all of it.
