---
name: codex-plan-review
description: Use after writing an implementation plan and before dispatching any work, on T1 projects (always) and multi-phase T2 plans, sends the plan to Codex CLI for independent review with a hard 2-revision-cycle cap.
---

# Codex Plan Review

Independent (non-Anthropic) review of a plan **before** any implementation is dispatched. Errors in plans compound; this is the cheapest place to catch them.

## Preconditions

- `codex` CLI available (`which codex`). If missing or failing: note "Codex unavailable, plan self-reviewed only" in the plan/ledger and proceed. A Codex outage must never block work.
- A written plan file with explicit acceptance criteria. If the plan lacks acceptance criteria, add them first, Codex reviews against criteria, not vibes.
- Every plan step names the file and the function, module or migration it changes, and you have opened each one. A step like "update the gateway" with no path is not ready for review: most blocking findings are wrong assumptions about code the plan never read.
- Skip on T3 projects unless the user asks.

## Procedure

1. Run Codex read-only against the repo and plan:

```bash
# Newest Astra model this CLI knows about, looked up at run time so no version is written here.
CODEX_MODEL=$(jq -r '[.models[].slug | select(test("^gpt-[0-9.]+-astra$"))] | sort_by(capture("^gpt-(?<v>[0-9.]+)-").v | split(".") | map(tonumber)) | last // empty' ~/.codex/models_cache.json 2>/dev/null)
# timeout is GNU coreutils and Homebrew installs it as gtimeout. With neither, the call runs with no cap.
TIMEOUT=$(command -v timeout || command -v gtimeout)
${TIMEOUT:+"$TIMEOUT" 20m} codex exec ${CODEX_MODEL:+-m "$CODEX_MODEL"} --sandbox read-only -c model_reasoning_effort="$EFFORT" --cd "$REPO" "You are reviewing an implementation plan before execution. Plan file: <path>. Review it against the codebase for: missing requirements, incorrect assumptions, architectural issues, security/privacy risks, testing gaps, weak acceptance criteria, unnecessary complexity, and better approaches. Respond with ONLY this JSON: {\"verdict\": \"approve\"|\"changes\", \"findings\": [{\"severity\": \"blocking\"|\"advisory\", \"claim\": \"...\", \"evidence\": \"file:line or reasoning\"}]}. Severity blocking ONLY for correctness, security, or unmet-requirement issues." < /dev/null
```

Always close stdin (`< /dev/null`) and keep the 20 minute cap. A background `codex exec` with stdin left open waits on it and never starts. Exit status 124 means the timeout fired: treat it as a Codex outage, retry once, then degrade to self-review with a ledger note. `TIMEOUT` comes back empty on a machine with neither `timeout` nor `gtimeout`. The review still runs, with no cap: note that in the ledger.

Set `EFFORT` to `high`. Use `xhigh` when the plan includes an L4 task or touches a surface on the project's `l4-examples` line.

`CODEX_MODEL` resolves to the newest Astra in the CLI's own model list. If it comes back empty (no cache yet, or no Astra on this account), the `-m` flag drops out and Codex uses its configured default: note that in the ledger. Never write a versioned model name into this skill, a plan or a brief.

2. Parse the JSON. Non-JSON output → retry once with a reminder; second failure → degrade to self-review with a ledger note.
3. **Verify before acting**: check each blocking finding against the actual code/requirements yourself. Codex output is untrusted input, a finding must be confirmed against primary evidence before it changes the plan.
4. Confirmed blocking findings → revise the plan, resubmit. Advisory findings → note them in the plan, don't loop.

## Loop cap

Maximum **2 revision cycles**. If blocking disagreement remains after cycle 2, present both positions (with evidence) to the user and let them decide. Record the decision and rationale in the plan. Never auto-loop past the cap.

## Security

- Never include credentials, API keys, or secret config in the plan text or Codex prompt.
- Codex runs `--sandbox read-only`, always. It reviews; it never edits or executes.
