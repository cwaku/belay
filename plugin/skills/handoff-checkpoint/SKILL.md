---
name: handoff-checkpoint
description: Use at the end of each task wave, before ending a long session, or when context/usage limits approach, writes a resumable, model-agnostic orchestration snapshot so any session (Fable, Opus, or Sonnet) can take over without lost or duplicated work.
---

# Handoff Checkpoint

All orchestration state must live in **durable artifacts a fresh session can read**, never only in conversation context. This is the entire fallback design: if a session dies or hits limits, a new session on any model resumes from the checkpoint. No live state transfer exists or is needed.

## Where the checkpoint lives

Priority order:
1. `checkpoint-file` declared in the project's `.claude/workflow.md`
2. `.superpowers/sdd/progress.md` if the project uses SDD
3. `PROGRESS.md` at the repo root (create it)

## What to write (every checkpoint)

```markdown
## Checkpoint <ISO date-time>
- Plan: <path to approved plan> (Codex-approved: yes/no/na)
- Phase/goal: <one line>
- Task graph:
  - [x] T1 <name>, commit <sha>, verified
  - [~] T2 <name>, dispatched (Sonnet, L2), brief at <path>, worktree <path>
  - [ ] T3 <name>, pending, blocked-on: T2
- Decisions this wave: <q → choice → why → by user|orchestrator>
- Validation state: <tests last run, result, command>
- Reviews: <internal/codex verdicts + open findings>
- Next action: <the single next step a resuming session should take>
```

## Resume protocol (for the session that picks up)

1. Read the checkpoint + project memory before doing anything.
2. For each task not marked verified: **check git first**, if a commit/branch exists matching the task, treat it as completed-pending-verification rather than redispatching. This makes takeover idempotent; completed work is never re-executed.
3. Only redispatch tasks with no corresponding commits, using the route recorded in their brief.
4. Continue at "Next action". Write a fresh checkpoint after the first wave.
5. Authority returns to the original model the same way, by reading the newest checkpoint. Nothing else transfers.

## Discipline

- Checkpoint after every completed task wave, not just at session end (limits arrive unannounced).
- The "Next action" line is mandatory, a checkpoint without it forces the resumer to re-derive intent.
- Convert relative dates to absolute. Reference commits by SHA, not "the last commit".
