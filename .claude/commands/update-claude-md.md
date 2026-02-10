# /update-claude-md

You are working in THIS repository. Your job is to update the project's CLAUDE.md as a durable, low-noise "future constraint" file.

## Goals
- Update CLAUDE.md to reflect ONLY stable, repo-specific guidance.
- Do NOT paste chat history, debugging logs, or transient experiments.
- Make it concise, actionable, and easy to follow for a fresh agent.

## What to scan
- Read: README, package/project config, entrypoints, folder structure, existing CLAUDE.md, and any docs that define workflows.
- Identify: how to run, test, lint, build, deploy (if present).
- Identify: architectural invariants and hard constraints.
- Identify: prohibited actions / foot-guns specific to this repo.

## Output requirements (write into CLAUDE.md)
Use this structure (keep sections short):
1) Project purpose (2–3 lines)
2) Quickstart (commands)
3) Architecture invariants (bullets)
4) Guardrails / do-not-do (bullets)
5) Conventions (naming, style, patterns)
6) Definition of done (what “finished” means here)

## Editing rules
- Preserve any existing good constraints; refactor for clarity.
- Remove duplicates and stale rules.
- If you are unsure, add a short TODO line instead of inventing facts.

Now: open CLAUDE.md (create if missing) and apply the update.
