# claude-workflow-kit

A multi-model orchestration workflow for [Claude Code](https://claude.com/claude-code), packaged as a plugin so it installs identically on every machine.

Most Claude Code setups run every subagent on the session's (often most expensive) model and review either everything or nothing. This kit implements a simpler discipline:

- **Route cheap work to cheap models.** Every delegated task gets an explicit model, chosen by a two-dimensional rubric: project risk tier × task complexity level.
- **Put independent review where defects actually surface.** Plans (errors compound) and phase gates (where structural defects show up) get a second, independent reviewer — a different model family via the Codex CLI. Per-task dual review is deliberately excluded: it adds latency, not defect yield.
- **Keep orchestration state in durable artifacts.** Checkpoints make any session — on any model — able to resume the work without losing or duplicating anything. Model fallback is just "read the checkpoint".

## The skills

| Skill | What it does |
|---|---|
| `task-router` | Routes every delegated task by **project tier** (T1 production / T2 personal product / T3 throwaway) × **task level** (L1 mechanical → L4 critical) to the right model and review depth, instead of inheriting the session model. Persists per-project config to `.claude/workflow.md`, creating it on first contact with a new project. Includes escalation and downgrade rules so the rubric self-corrects. |
| `codex-plan-review` | Independent review of implementation plans before any work is dispatched (T1 always, T2 multi-phase only). Blocking-only severity, hard 2-revision-cycle cap, and every finding is verified against primary evidence before it changes the plan. |
| `codex-gate-review` | Dual sign-off at phase gates and L4 tasks only. The reviewer receives the real diff, executed test output, and acceptance criteria — never summaries. Credentials are redacted from the package; a reviewer outage degrades gracefully and never blocks shipping. |
| `handoff-checkpoint` | Model-agnostic orchestration snapshots: task graph with status, decisions, validation state, and a mandatory "next action" line. The resume protocol checks git for existing commits before redispatching anything, so takeover is idempotent. |

## What it looks like

First contact with an untiered project costs exactly one question, once:

> **User:** Add CSV export for invoices in billflow.
>
> **Claude:** Billflow has no `.claude/workflow.md` yet — inferring **T2 Personal product**, confirm? *(user confirms)* Persisted. Routing: L2 Standard → **Sonnet, medium effort**, spot-check review only — no gate ceremony, because a pre-launch app at L2 doesn't earn any.

Full transcript from a real session: [docs/demo.md](docs/demo.md).

## Install

**Plugin (preferred).** In Claude Code:

```
/plugin marketplace add cwaku/claude-workflow-kit
/plugin install workflow-kit@claude-workflow-kit
```

**Plain copy (fallback):**

```bash
git clone https://github.com/cwaku/claude-workflow-kit.git
cd claude-workflow-kit && ./install.sh
```

Don't use both methods on the same machine — the skills would register twice.

**Make it instruction-strength.** Skills are discovered by description; the strongest guarantee is a standing instruction loaded into every session. Copy `templates/CLAUDE.md` to `~/.claude/CLAUDE.md` (the installer does this if you don't already have one) or merge its bullets into your existing file.

## Per-project setup

Each project declares its risk tier in `<project>/.claude/workflow.md` — template in [`templates/workflow.md`](templates/workflow.md). If the file is missing, `task-router` infers a tier, asks you once, and writes it. The tier shifts the entire review ladder, so coursework never pays production-grade overhead and production paths never get coursework-grade review.

## Requirements

- Claude Code with plugin support.
- Optional: [Codex CLI](https://github.com/openai/codex), authenticated (`codex login`), for the two review skills. Without it they log "Codex unavailable" and fall back to internal review — nothing blocks. Any independent reviewer CLI could be substituted by editing the two skills' command lines.

## Design notes

- **Why a second model family for review?** Same-family review (a model reviewing its own family's output) shares blind spots. Independence is the point — and it's reserved for the two places it pays: plans and gates.
- **Why capped review loops?** Reviewer disagreement without a cap becomes an infinite approval loop. Two cycles, then a human decides; overrides are logged, never silent.
- **What's deliberately not here:** learned/automatic routing, agent federation, background workers, external state stores. The kit is conventions over infrastructure — everything runs on Claude Code's own primitives and degrades to plain Claude Code if any piece is missing.
- Project-specific skills (e.g. a repo's production-shape checks or environment preflight) belong in that repo's own `.claude/skills/`, versioned with the code they describe — not in this kit.

## License

[MIT](LICENSE)
