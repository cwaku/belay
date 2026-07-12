# claude-workflow-kit

Multi-model orchestration workflow for Claude Code, packaged as a plugin so it installs identically on every machine.

Four skills that together implement a simplified advisor–orchestrator architecture:

| Skill | What it does |
|---|---|
| `task-router` | Routes every delegated task by **project tier** (T1 production / T2 personal product / T3 throwaway) × **task level** (L1 mechanical → L4 critical) to the right model (Sonnet/Opus) and review depth, instead of inheriting the session model. Persists per-project config to `.claude/workflow.md`. |
| `codex-plan-review` | Independent (OpenAI Codex) review of implementation plans before any work is dispatched. Blocking-only severity, hard 2-revision-cycle cap, findings verified against primary evidence. |
| `codex-gate-review` | Dual sign-off at phase gates and L4 tasks only — Codex reviews the real diff + executed test output + acceptance criteria. Degrades gracefully if Codex is unavailable. |
| `handoff-checkpoint` | Model-agnostic orchestration snapshots (task graph, decisions, validation state, next action) so any session — Fable, Opus, or Sonnet — can resume without lost or duplicated work. |

Design rationale: route cheap work to cheap models; put independent review where defects actually surface (plans and phase gates, not every task); keep all orchestration state in durable artifacts so model fallback is just "read the checkpoint".

## Install (plugin — preferred)

In Claude Code on the target machine:

```
/plugin marketplace add cwaku/claude-workflow-kit
/plugin install workflow-kit@claude-workflow-kit
```

## Install (plain copy — fallback)

```bash
git clone git@github.com:cwaku/claude-workflow-kit.git
cd claude-workflow-kit && ./install.sh
```

Don't use both methods on the same machine — the skills would be registered twice.

## Per-project setup

Each project declares its risk tier in `<project>/.claude/workflow.md` (template in `templates/workflow.md`). If the file is missing, `task-router` infers a tier, confirms once, and writes it.

## Requirements

- Claude Code with plugin support.
- [Codex CLI](https://github.com/openai/codex) authenticated (`codex login`) for the two review skills. Without it they log "Codex unavailable" and fall back to internal review — nothing blocks.

## Not included

Project-specific skills (e.g. a repo's production-shape checks or environment preflight) belong in that repo's own `.claude/skills/`, versioned with the code they describe.
