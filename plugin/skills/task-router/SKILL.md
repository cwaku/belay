---
name: task-router
description: Use when dispatching subagents, executing a plan, or delegating any implementation/review task — determines the project risk tier and task complexity level, then routes to the right model (Sonnet/Opus/Fable) and review depth instead of inheriting the session model.
---

# Task Router

Route every delegated task by **project tier × task level**. Never dispatch a subagent with an unconsidered (inherited) model.

## Step 1 — Determine the project tier (once per project)

Read `.claude/workflow.md` in the project root. If it declares a tier, use it.

If it doesn't exist: infer a tier from the checklist below, confirm with the user in one question, then **persist the answer** by writing `.claude/workflow.md`:

```markdown
# Workflow config
tier: T1 | T2 | T3
l4-examples: <project-specific critical surfaces, e.g. "auth endpoints, data deletion">
checkpoint-file: <path, default PROGRESS.md or .superpowers/sdd/progress.md if SDD in use>
```

| Tier | Definition | Examples |
|------|-----------|----------|
| **T1 Production** | Real money, real users, credentials, or irreversible data. Failure has external cost. | quant-portfolio (live trading), scanbox_api if deployed |
| **T2 Personal product** | Apps you intend to keep/ship but nothing external breaks yet. | billflow, debitty, pre-launch projects |
| **T3 Throwaway / coursework** | Assignments, experiments, one-offs. Correct-enough beats hardened. | SAIT coursework, student portal, demos |

## Step 2 — Level the task

| Level | Criteria (any one qualifies) | Model |
|-------|------------------------------|-------|
| **L1 Mechanical** | Spec fully written; single file or pattern-following; failure obvious and cheap | Sonnet, low/medium effort |
| **L2 Standard** | Defined feature, existing patterns, ≤3 modules, testable criteria | Sonnet, medium effort |
| **L3 Complex** | Ambiguous spec; cross-cutting (≥4 modules or a language/service boundary); concurrency; performance-sensitive; novel algorithm | Opus, high effort |
| **L4 Critical** | Irreversible actions, credentials/security, production user-facing surface, or failure that would be **silent** in production. Each project's `l4-examples` line names its own instances. | Opus or orchestrator-direct, high effort |

## Step 3 — Review ladder (tier shifts the whole ladder)

| | T1 | T2 | T3 |
|---|---|---|---|
| L1 | hooks + spot-check | hooks only | hooks only |
| L2 | single review pass | spot-check | none beyond tests |
| L3 | review + phase-gate review | single review pass | spot-check |
| L4 | review + phase gate + `codex-gate-review` + **human approval** | review + human approval | single review pass |

Plan review (`codex-plan-review`): T1 always, T2 for multi-phase plans, T3 skip.

## Step 4 — Record and dispatch

Record `level`, `route`, and `tier` in the task brief (or task list item) before dispatching, so routing is auditable. Pass `model` and `effort` explicitly on the Agent/Workflow call.

## Escalation and downgrade

- **Escalate one level** when: the worker fails acceptance criteria twice; the diff grows >2× the estimate; the worker reports material spec ambiguity; review finds a correctness (not style) defect. Record `escalated_from`.
- **Downgrade one level** for a task type after it passes 3 consecutive reviews/gates with zero findings at its current level.
- Duplicate-implementation (two independent workers, compare outputs) is an L4/T1-only tactic — never use it for deterministic tasks.
