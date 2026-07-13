# Standing workflow (all projects)

- Before dispatching any subagent or executing a plan, invoke the `task-router` skill: route by project tier (from `.claude/workflow.md`, create via the skill if missing) × task level. Pass explicit `model`/`effort` on every Agent/Workflow call; never let workers silently inherit the session model.
- T1 projects: `codex-plan-review` before dispatching plan work; `codex-gate-review` at phase gates and L4 tasks before the human-confirmed merge. T3 (coursework/throwaway) projects skip Codex entirely.
- After each completed task wave and before ending long sessions, run `handoff-checkpoint`.
- Review loops are capped at 2 revision cycles; after that, present both positions to me and I decide.
