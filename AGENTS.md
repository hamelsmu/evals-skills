# Repository Instructions

This repository is a catalog of agent skills for LLM evaluation work.

- Canonical skill content lives in `skills/*/SKILL.md`.
- `.agents/skills/*` exists for Codex discovery and should stay as symlinks to the canonical skill folders.
- When a skill's behavior or recommended invocation changes, update `README.md` in the same change.
- Validate Codex support from the repo root with `codex --ask-for-approval never "Summarize the current instructions."`, `/skills`, and at least one explicit `$skill-name` invocation.
