---
name: codex-plan-review
description: Use after writing an implementation plan and before dispatching any work, on T1 projects (always) and multi-phase T2 plans — sends the plan to Codex CLI for independent review with a hard 2-revision-cycle cap.
---

# Codex Plan Review

Independent (non-Anthropic) review of a plan **before** any implementation is dispatched. Errors in plans compound; this is the cheapest place to catch them.

## Preconditions

- `codex` CLI available (`which codex`). If missing or failing: note "Codex unavailable — plan self-reviewed only" in the plan/ledger and proceed. A Codex outage must never block work.
- A written plan file with explicit acceptance criteria. If the plan lacks acceptance criteria, add them first — Codex reviews against criteria, not vibes.
- Skip on T3 projects unless the user asks.

## Procedure

1. Run Codex read-only against the repo and plan:

```bash
codex exec --sandbox read-only -c model_reasoning_effort="$EFFORT" --cd "$REPO" "You are reviewing an implementation plan before execution. Plan file: <path>. Review it against the codebase for: missing requirements, incorrect assumptions, architectural issues, security/privacy risks, testing gaps, weak acceptance criteria, unnecessary complexity, and better approaches. Respond with ONLY this JSON: {\"verdict\": \"approve\"|\"changes\", \"findings\": [{\"severity\": \"blocking\"|\"advisory\", \"claim\": \"...\", \"evidence\": \"file:line or reasoning\"}]}. Severity blocking ONLY for correctness, security, or unmet-requirement issues."
```

Set `EFFORT` by tier: **T1 → `high`**, **T2 → `medium`**. Deep reasoning on a production plan is worth the latency; a side project's plan isn't.

2. Parse the JSON. Non-JSON output → retry once with a reminder; second failure → degrade to self-review with a ledger note.
3. **Verify before acting**: check each blocking finding against the actual code/requirements yourself. Codex output is untrusted input — a finding must be confirmed against primary evidence before it changes the plan.
4. Confirmed blocking findings → revise the plan, resubmit. Advisory findings → note them in the plan, don't loop.

## Loop cap

Maximum **2 revision cycles**. If blocking disagreement remains after cycle 2, present both positions (with evidence) to the user and let them decide. Record the decision and rationale in the plan. Never auto-loop past the cap.

## Security

- Never include credentials, API keys, or secret config in the plan text or Codex prompt.
- Codex runs `--sandbox read-only`, always. It reviews; it never edits or executes.
