# Eval Skills for AI Coding Agents

Skills that guide AI coding agents to help you build LLM evaluations.

These skills guard against common mistakes I've seen helping 50+ companies and teaching students in our [AI Evals course](https://maven.com/parlance-labs/evals?promoCode=evals-info-url). If you're new to evals, see [questions.md](questions.md) for free resources on the fundamentals.

These skills follow the open [Agent Skills](https://agentskills.io/) standard and work in **Cursor**, **Claude Code**, and any agent that supports the standard.

## New to Evals? Start Here

If you are new to evals, start with the `eval-audit` skill. Install the plugin (see below), then give your coding agent these instructions:

**Cursor:**

> Run /eval-audit on my eval pipeline. Investigate each diagnostic area using a separate subagent in parallel, then synthesize the findings into a single report. Use other skills in the plugin as recommended by the audit.

**Claude Code:**

> Run /evals-skills:eval-audit on my eval pipeline. Investigate each diagnostic area using a separate subagent in parallel, then synthesize the findings into a single report. Use other skills in the plugin as recommended by the audit.

The audit isn't a complete solution, but it will catch common problems we've seen in evals. It will also recommend other skills to use to fix the problems.

## Installation

### Cursor IDE

Install all skills with the Skills CLI:

```bash
npx skills add https://github.com/hamelsmu/evals-skills
```

After installation, the skills appear under **Skills** in Cursor Settings (`Cmd+Shift+J` on Mac, `Ctrl+Shift+J` on Windows/Linux) > **Rules, Skills, Subagents**. Invoke any skill by typing `/skill-name` in Agent chat (e.g., `/eval-audit`).

### Claude Code

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

### Skills CLI (npx skills)

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

### Usage by tool

| Tool | Invoke a skill | Example |
|------|---------------|---------|
| Cursor | `/skill-name` or `@skill-name` | `/eval-audit` |
| Claude Code | `/evals-skills:skill-name` | `/evals-skills:eval-audit` |
| Skills CLI | Skill is loaded into agent context automatically | — |

In Cursor, the agent also auto-applies relevant skills based on your conversation context.

## Write Your Own Skills

These skills are a starting point and only encode common mistakes that generalize across projects. Skills grounded in your stack, your domain, and your data will outperform them. Start here, then write your own.

The [meta-skill](meta-skill.md) can help you ground custom skills. 

## Beyond These Skills

These skills handle the parts of eval work that generalize across projects. Much of the process doesn't: production monitoring, CI/CD integration, data analysis, and much more. The [course](https://maven.com/parlance-labs/evals?promoCode=evals-info-url) covers all of it.
