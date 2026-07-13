# Demo: first contact with an untiered project

A real session transcript, lightly trimmed. The user asks for a feature in a project
that has no `.claude/workflow.md` yet. Belay's `task-router` infers a tier, confirms once,
saves the config, and routes the task. Total overhead: one question, once per project.

---

> **You:** Add CSV export for invoices in billflow.

**Claude:** Routing this through `task-router` before dispatching. Billflow has no
`.claude/workflow.md` yet. It looks like a pre-launch Elixir/Phoenix billing app
(no deployment config, no live credentials), so I'd infer **T2 Personal product**.

```
┌ billflow tier ──────────────────────────────────────────────┐
│ What tier is billflow? (saved to .claude/workflow.md)        │
│                                                              │
│ ❯ T2 Personal product (Recommended)                          │
│   T1 Production: real users, money, or credentials today     │
│   T3 Throwaway: experiment or one-off                        │
└──────────────────────────────────────────────────────────────┘
```

> **You:** *T2 Personal product*

**Claude:** Saved. This question never comes back for billflow:

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
| Level | **L2 Standard**: defined feature, existing controller/context patterns to follow, testable criteria |
| Route | **Sonnet, medium effort** (not the session model) |
| Review | T2 × L2 means a spot-check only, with no Codex involvement |

Dispatching to a Sonnet worker with the brief. The worker implements, the orchestrator
spot-checks the diff against the acceptance criteria, and that's it. No gate ceremony,
because a pre-launch app at L2 hasn't earned any.

---

The same request in a **T1** project would route identically (L2 still goes to Sonnet) but
pick up the fuller review ladder. And a task touching billflow's `l4-examples` surfaces
(payments, auth, destructive migrations) would escalate to **Opus plus human approval**
even at T2. That's the whole idea: review depth follows risk, not habit.
