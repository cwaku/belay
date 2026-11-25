# Standing workflow (all projects)

- Before dispatching any subagent or executing a plan, invoke the `task-router` skill: route by project tier (from `.claude/workflow.md`, create via the skill if missing) × task level. Pass explicit `model`/`effort` on every Agent/Workflow call; never let workers silently inherit the session model.
- T1 projects: `codex-plan-review` before dispatching plan work; `codex-gate-review` at phase gates and L4 tasks before the human-confirmed merge. T2 projects: `codex-gate-review` on L4 tasks, also before the merge. T3 (coursework/throwaway) projects skip Codex entirely.
- After each completed task wave and before ending long sessions, run `handoff-checkpoint`.
- Review loops run 2 passes, then a third and a fourth only while each pass has fewer confirmed blocking findings than the one before. A refuted finding that comes back, a count that doesn't fall, or a pass 4 that is still blocked ends the loop: present both positions to me and I decide.
