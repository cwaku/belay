# Belay

**Sensible protection for AI-driven development.**

Most Claude Code setups do two things badly. Every delegated task runs on the most expensive model, whether it needs it or not. And review is all-or-nothing: either every change gets scrutinized or none of them do. Belay replaces both habits with something simpler.

- **Work is routed by risk.** A small rubric (project tier times task level) picks the model and effort for each delegated task. Mechanical work runs cheap, critical work runs strong, and nothing silently inherits your session model.
- **Independent review happens where it pays.** Plans get a second opinion before any work starts, because errors in plans compound. Phase gates get one before merge, because that's where structural defects actually surface. Reviewing every single task is deliberately not part of this. It adds latency, not safety.
- **Progress survives interruptions.** Checkpoints keep orchestration state in plain files that any session, on any model, can pick up. If a session dies mid-feature, the next one reads the checkpoint and continues. Nothing is lost and nothing gets done twice.

There are no queues, daemons, or state stores here. Belay is a set of conventions packed into four skills. It runs on Claude Code's own primitives, and if any piece is missing it degrades to plain Claude Code.

## What it looks like

![Belay's first contact: it infers the tier, asks once, saves workflow.md, and routes the task to Sonnet](docs/demo.gif)

*A real session ([full transcript](docs/demo.md), or replay it with `asciinema play docs/demo.cast`).*

The first time Belay meets a project, it costs you one question:

> **You:** Add CSV export for invoices in billflow.
>
> **Claude:** Billflow has no `.claude/workflow.md` yet. It looks like a pre-launch app, so I'd say tier T2. Confirm? *(you confirm)* Saved. Routing: L2 standard task, so Sonnet at medium effort with a spot-check review. No heavier ceremony, because a pre-launch app at L2 hasn't earned any.

That's it. The answer is saved and the question never comes back for that project.

## The four skills

| Skill | What it does for you |
|---|---|
| `task-router` | Decides who does each piece of work. **Project tier** (T1 production, T2 personal product, T3 throwaway) times **task level** (L1 mechanical up to L4 critical) picks the model, the effort, and how much review the result gets. When a worker struggles, it retries at higher effort before reaching for a bigger model. Task types that keep reviewing clean get routed cheaper over time. |
| `codex-plan-review` | Gets a second opinion on your plan before any work is dispatched. The reviewer is OpenAI Codex, a different model family on purpose. Only blocking findings (correctness, security, unmet requirements) can send a plan back, there's a hard cap of two revision rounds, and every finding is checked against the actual code before it changes anything. |
| `codex-gate-review` | The same independent reviewer, at the moments that matter: phase gates and L4 tasks. It reads your real diff, your executed test output, and your acceptance criteria. Never summaries. If Codex is down, you're told and the internal review carries on alone. An outage never blocks a merge. |
| `handoff-checkpoint` | Writes down where things stand after each batch of work: the task graph, decisions made, test state, and a required "next action" line. A resuming session checks git before redispatching anything, so completed work is recognized instead of repeated. |

## Install

**As a plugin (recommended).** In Claude Code:

```
/plugin marketplace add cwaku/belay
/plugin install belay@belay
```

**Or as a plain copy:**

```bash
git clone https://github.com/cwaku/belay.git
cd belay && ./install.sh
```

Pick one. Installing both ways registers every skill twice.

**Then make it stick.** Skills trigger by description, which works most of the time. The strongest guarantee is a standing instruction that loads into every session. `install.sh` copies `templates/CLAUDE.md` to `~/.claude/CLAUDE.md` if you don't have one yet. If you do, it leaves yours alone and you merge the few bullets yourself.

## How you'll actually use it

Mostly, you won't notice it. You prompt the way you always have, and Belay activates on delegation-shaped work: plans being executed, tasks being handed to subagents. Not on every message.

- **A project you've already tiered:** routing is silent. The decision shows up in the task brief and that's all you see.
- **A new project:** one tier question, then never again.
- **Small direct work**, like "fix this typo": nothing activates, which is correct. Worth knowing: work you don't delegate runs on your session model. Belay manages the work you hand off, not the conversation itself.
- **A big feature in a production project:** plan review, then routed dispatch, checkpoints along the way, a gate review at the end, and the merge always stops and asks you. On a clean run your total involvement is the original prompt and one yes.

One honest caveat. Activation is instruction-driven, not mechanically enforced, so a session can occasionally blow past it. Saying "use task-router" fixes it on the spot. If you want hard enforcement, add a `PreToolUse` hook that flags any Agent call missing an explicit model.

## Moving to a new machine

Belay installs only its own four skills. The rest of your environment (plugins, personal skills, your global `CLAUDE.md`) lives in `~/.claude/` and doesn't move by itself. Two scripts handle that: `export-setup.sh` bundles your setup on the old machine, `import-setup.sh` restores it on the new one.

One thing to know first: **these scripts live in the belay repo, not in the marketplace plugin.** Installing belay from the marketplace gives you the four skills and nothing else. To export or import, you need a clone of this repo on that machine.

**On your old machine**, from a belay clone:

```bash
./scripts/export-setup.sh          # writes my-setup/ (plugin names, skills, CLAUDE.md)
```

Commit `my-setup/` to a dotfiles repo and push it, so the new machine can pull it. (It contains no secrets by construction. See the publishing notes below.)

**On your new machine**, where you've installed belay from the marketplace and cloned your dotfiles:

```bash
git clone https://github.com/cwaku/belay.git    # get the scripts; the plugin doesn't include them
cd belay
./scripts/import-setup.sh --from ~/your-dotfiles # point --from at your cloned dotfiles repo
```

`--from` is the flag that reads your setup from the cloned dotfiles repo instead of a local `my-setup/`. Two non-interactive shortcuts skip the picker:

```bash
./scripts/import-setup.sh --from ~/your-dotfiles --recommended   # just the Belay-paired plugins
./scripts/import-setup.sh --from ~/your-dotfiles --all           # everything you exported
```

The script needs `jq` installed, backs up `~/.claude/settings.json` before merging, and won't overwrite an existing global `CLAUDE.md`, so it's safe to re-run if a step fails.

The importer walks through each plugin and skill and asks what you want. Three plugins pair well with Belay and default to yes: `superpowers` for plan-execution discipline, `claude-mem` for cross-session memory, and `code-review` for the internal pass the gate review runs alongside. Everything else defaults to no, so someone using your dotfiles adopts your setup deliberately rather than wholesale.

**You can publish your export as public dotfiles.** It contains no secrets by construction, just plugin names and marketplace repos. Scan yours before publishing anyway: `grep -rniE "api[_-]?key|secret|token|password" my-setup/`. The export directory is gitignored in this repo so Belay itself stays generic. The author's [claude-dotfiles](https://github.com/cwaku/claude-dotfiles) shows the layout, consumed with `--from`.

Three things to know before publishing:

1. Exported skills are often vendored third-party work. Keep their attribution and check upstream licenses, or exclude machine-managed ones: `EXPORT_SKIP="omarchy" ./scripts/export-setup.sh`.
2. Plugin data stays put. A memory plugin's database doesn't travel, only its installation.
3. Marketplaces that were added interactively can't be read from settings. The importer detects those and prints the exact `/plugin` commands to finish the job.

## Per-project setup

Each project declares its tier in `<project>/.claude/workflow.md` ([template](templates/workflow.md)), along with its own list of critical surfaces, the things that always get maximum protection. For an API that might be auth endpoints and data deletion. For a trading system, order execution. If the file doesn't exist, `task-router` infers a tier, confirms with you once, and writes it. The tier shifts the entire review ladder, so coursework never pays production-grade overhead and production paths never get coursework-grade review.

## What you need

- Claude Code with plugin support.
- Optionally, the [Codex CLI](https://github.com/openai/codex), authenticated with `codex login`, for the two review skills. Without it they say so and fall back to internal review. Nothing blocks. Any other reviewer CLI can be swapped in by editing two command lines.

## Why it's built this way

- **Why a different model family for review?** A model reviewing its own family's output shares its blind spots. Independence is what makes the second opinion worth having, and it's spent only where it pays: plans and gates.
- **Why capped review loops?** Two reviewers disagreeing without a cap is an infinite approval loop. Two rounds, then you decide, and overrides are logged rather than silent.
- **What's deliberately missing:** learned routing, agent federation, background workers, external state stores. Heavier platforms exist if that's what you want. Belay stays small on purpose, because every piece it doesn't have is a piece that can't break, drift, or need maintenance.
- Project-specific skills (a repo's production-shape checks, its environment preflight) belong in that repo's own `.claude/skills/`, versioned with the code they protect. Not here.

## License

[MIT](LICENSE)
