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

![task-router first contact: infers the tier, asks once, persists workflow.md, routes the task to Sonnet](docs/demo.gif)

*Animated rendering of a real session ([full transcript](docs/demo.md); replay locally with `asciinema play docs/demo.cast`).*

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

## Usage — what actually triggers, and when

You don't invoke anything. Prompt normally; the workflow fires on **delegation-shaped work** — when a plan is executed or a task is handed to a subagent — not on every prompt.

- **Project already set up:** routing is silent. The router reads `.claude/workflow.md`, levels the task, dispatches to the right model. You see the routing decision in the task brief, nothing else.
- **First contact with a new project:** the one tier question (see the demo above), then persisted forever. A brand-new empty folder just means this happens on day one.
- **Small direct work** ("fix this typo", "explain this function"): nothing triggers, correctly — the main session handles it. Caveat: undelegated work runs on your *session* model. The kit optimizes delegated tasks; it doesn't reroute the conversation itself.
- **Big feature in a T1 project** — the full chain, in sequence, automatically: plan → `codex-plan-review` (you hear about it only on blocking findings or when the 2-cycle cap escalates to you) → tasks routed → checkpoints per wave → phase gate review → **the merge always stops and asks you**. Your involvement on the happy path: the original prompt and the merge confirmation.

**Routing granularity:** the tier question is once per project; the level decision is per task at dispatch time (one plan can route L1 work to a cheap model and L4 work to an expensive one); escalation can re-route mid-task when a worker fails its criteria twice, and task types that repeatedly review clean get downgraded one level.

**Honest caveat:** triggering is instruction-driven (global `CLAUDE.md` + skill descriptions), not mechanically enforced — a session can occasionally barrel past it. Saying "use task-router" fixes it on the spot. For deterministic enforcement, add a `PreToolUse` hook that flags Agent calls without an explicit model.

## Per-project setup

Each project declares its risk tier in `<project>/.claude/workflow.md` — template in [`templates/workflow.md`](templates/workflow.md). If the file is missing, `task-router` infers a tier, asks you once, and writes it. The tier shifts the entire review ladder, so coursework never pays production-grade overhead and production paths never get coursework-grade review.

## Carrying the rest of your setup

The kit installs only its own four skills. Your wider Claude Code environment — plugins (memory systems, review tooling, design skills…) and personal skills in `~/.claude/skills/` — lives in `~/.claude/settings.json` and doesn't transfer by itself. Two scripts close that gap:

```bash
./scripts/export-setup.sh   # on your current machine → writes my-setup/
./scripts/import-setup.sh   # on the new machine → merges it in
```

Export captures your plugin/marketplace declarations, personal skills (minus the kit's own), and global `CLAUDE.md`. Import merges the plugin config into the target's `settings.json` (backup taken, local entries win on conflict), copies skills without overwriting, and never touches an existing `CLAUDE.md`.

`my-setup/` is **gitignored** — your personal configuration stays out of this repo. Move it between machines however you like, or commit it on a private fork. Two caveats: plugin *data* doesn't transfer (a memory plugin's database stays where it was), and if a declared plugin doesn't activate on first launch, the import script prints the exact `/plugin` commands to finish interactively.

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
