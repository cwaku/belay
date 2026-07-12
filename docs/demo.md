# Demo: first contact with an untiered project

A real session transcript (lightly trimmed): the user asks for a feature in a project
that has no `.claude/workflow.md` yet. `task-router` infers a tier, confirms once,
persists the config, and routes the task — total overhead: one question, once per project.

---

> **User:** Add CSV export for invoices in billflow.

**Claude:** Before dispatching, routing this via `task-router`. Billflow has no
`.claude/workflow.md` yet — it looks like a pre-launch Elixir/Phoenix billing app
(no deployment config, no live credentials), so I'd infer **T2 Personal product**.

```
┌ billflow tier ──────────────────────────────────────────────┐
│ task-router needs billflow's risk tier (persisted to        │
│ billflow/.claude/workflow.md). What tier is billflow?       │
│                                                              │
│ ❯ T2 Personal product (Recommended)                          │
│   T1 Production — real users/money/credentials today         │
│   T3 Throwaway — experiment or one-off                       │
└──────────────────────────────────────────────────────────────┘
```

> **User:** *T2 Personal product*

**Claude:** Persisted — this question never gets asked again for billflow:

```markdown
# billflow/.claude/workflow.md
tier: T2
l4-examples: payment-provider integration, auth/session handling, destructive data migrations
checkpoint-file: PROGRESS.md
notes: Pre-launch Elixir/Phoenix billing app. Re-tier to T1 at launch.
```

Routing the task:

| | |
|---|---|
| Task | CSV export for invoices |
| Level | **L2 Standard** — defined feature, existing controller/context patterns to follow, ≤3 modules, testable criteria |
| Route | **Sonnet, medium effort** (not the session model) |
| Review | T2 × L2 → spot-check only; no Codex involvement |

Dispatching to a Sonnet worker with the brief… *(worker implements; orchestrator
spot-checks the diff against the acceptance criteria; done — no gate ceremony,
because a pre-launch app at L2 doesn't earn any)*

---

The same request in a **T1** project would route identically (L2 → Sonnet) but pick up
the fuller review ladder; a task touching billflow's `l4-examples` surfaces (payments,
auth, destructive migrations) would escalate to **Opus + human approval** even at T2.
That's the whole idea: review depth follows risk, not habit.
