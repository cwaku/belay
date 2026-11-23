---
name: task-router
description: Use when dispatching subagents, executing a plan, delegating any implementation or review task, or choosing which model a session should run on. Routes by project risk tier and task level so no worker or reviewer inherits the session model by default.
---

# Task Router

Route every delegated task by **project tier × task level**. Never dispatch a subagent with an unconsidered (inherited) model.

## Step 1: Determine the project tier (once per project)

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
| **T1 Production** | Real money, real users, credentials, or irreversible data. Failure has external cost. | A deployed SaaS API, a live trading system, anything holding customer data |
| **T2 Personal product** | Apps you intend to keep/ship but nothing external breaks yet. | Pre-launch side projects, internal tools |
| **T3 Throwaway / coursework** | Assignments, experiments, one-offs. Correct-enough beats hardened. | School assignments, prototypes, demos, spikes |

## Step 1b: Check the orchestrator (session) model

The orchestrator plans, writes briefs, rules on findings and keeps the checkpoint, so it is usually the largest single cost in a session. When the tier is set, compare the session model to this table:

| Tier | Session model |
|------|---------------|
| T1 | `fable` |
| T2 | `opus` |
| T3 | `sonnet` |

The order is `sonnet`, then `opus`, then `fable`. If the session runs above its row, say so once in one line and carry on. The user's choice of model always wins.

Orchestrator-direct work is for L4, or for a task of about five edits or fewer. Anything larger at L1 to L3 goes to a worker at the routed model, even when doing it inline looks faster.

## Step 2: Level the task

| Level | Criteria (any one qualifies) | Model | Effort |
|-------|------------------------------|-------|--------|
| **L1 Mechanical** | Spec fully written; single file or pattern-following; failure obvious and cheap | `sonnet` | `low` |
| **L2 Standard** | Defined feature, existing patterns, ≤3 modules, testable criteria | `sonnet` | `medium` |
| **L3 Complex** | Ambiguous spec; cross-cutting (≥4 modules or a language/service boundary); concurrency; performance-sensitive; novel algorithm | `opus` | `high` |
| **L4 Critical** | Irreversible actions, credentials/security, production user-facing surface, or failure that would be **silent** in production. Each project's `l4-examples` line names its own instances. | `opus` or orchestrator-direct | `high` |

Pass **both** `model` and `effort` explicitly on every Agent/Workflow call, an unconsidered effort is the same mistake as an unconsidered model, just smaller.

Model names are family aliases: `sonnet`, `opus`, `fable`. Never write a versioned model ID in a call, a brief, a plan or `workflow.md`. An alias follows the newest version in its family, so nothing here changes when one ships. The Codex skills pick their model the same way.

## Step 3: Review ladder (tier shifts the whole ladder)

| | T1 | T2 | T3 |
|---|---|---|---|
| L1 | hooks + spot-check | hooks only | hooks only |
| L2 | single review pass | spot-check | none beyond tests |
| L3 | review + phase-gate review | single review pass | spot-check |
| L4 | review + phase gate + `codex-gate-review` + **human approval** | review + human approval | single review pass |

Plan review (`codex-plan-review`): T1 always, T2 for multi-phase plans, T3 skip.

Reviewer routing, by the term the ladder uses. A reviewer is a fresh subagent that did not write the work:

| Ladder term | Model | Effort |
|-------------|-------|--------|
| "spot-check", and any re-review of a fix | `sonnet` | `medium` |
| "review" or "single review pass" on an L1 to L3 task | `opus` | `high` |
| "phase gate" or whole-branch review, and every review of an L4 task | `opus` | `xhigh` |

## Step 4: Record and dispatch

Record `level`, `route`, and `tier` in the task brief (or task list item) before dispatching, so routing is auditable. Pass `model` and `effort` explicitly on the Agent/Workflow call.

After each review, add one line to the checkpoint's review ledger: task type, level, reviewer route, number of blocking findings.

## Escalation and downgrade

- **Effort first, model second.** On the worker's *first* failure against acceptance criteria, retry the same model one effort tier up (`low`→`medium`→`high`), an effort bump is far cheaper than a model jump and often sufficient.
- **Escalate one level** (model jump) when: the effort-bumped retry also fails; the diff grows >2× the estimate; the worker reports material spec ambiguity; review finds a correctness (not style) defect. Record `escalated_from`.
- **Downgrade one level** for a task type after it passes 3 consecutive reviews/gates with zero findings at its current level. Count them from the review ledger, not from memory.
- Duplicate-implementation (two independent workers, compare outputs) is an L4/T1-only tactic, never use it for deterministic tasks.
