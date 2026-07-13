---
name: codex-gate-review
description: Use at phase gates on T1 projects and for L4 tasks, independent Codex completion review of the branch diff, test output, and acceptance criteria before merge. Dual sign-off instrument; not for per-task use.
---

# Codex Gate Review

Second, independent sign-off at **phase gates** (T1) and **L4 tasks**. Runs alongside, never instead of, the internal `/code-review` pass. Do not run per-task on L1–L3; evidence shows per-task dual review adds latency, not defect yield.

## Evidence package (primary evidence, never summaries)

Build before invoking Codex:
1. `git diff <base>...<branch> > /tmp/gate-review.diff` (the actual diff, not a description)
2. Executed test output (run the suite; capture real output, "tests pass" claims are not evidence)
3. The acceptance criteria from the approved plan
4. For L4: the production-shape/verification transcript if the project has one

## Procedure

```bash
codex exec --sandbox read-only -c model_reasoning_effort="high" --cd "$REPO" "You are the independent completion reviewer. Inputs: diff at /tmp/gate-review.diff, test log at <path>, acceptance criteria: <criteria>. Review for: correctness, completeness vs the criteria, code quality, architecture, security, test coverage, regression risk, and compliance with the approved plan. Inspect the diff and the codebase directly, do not trust any summary. Respond with ONLY this JSON: {\"verdict\": \"approve\"|\"blocked\", \"findings\": [{\"severity\": \"blocking\"|\"advisory\", \"claim\": \"...\", \"evidence\": \"file:line\", \"criterion\": \"which acceptance criterion this affects, if any\"}]}. Blocking ONLY for correctness defects, unmet criteria, security exposure, or silent-in-production failure modes."
```

Gate reviews always run at `model_reasoning_effort="high"`, this skill only fires where risk already justified it (T1 gates, L4 tasks), so there is no cheap tier here. If latency matters, the lever is *whether* the gate runs (task-router's ladder), never how hard the reviewer thinks.

- Parse JSON; retry once on malformed output; then degrade to internal-review-only with a ledger note. Codex outage never blocks shipping.
- **Verify each blocking finding against the code before acting.** Confirmed → fix wave, routed per task-router. Refuted → one written rebuttal with evidence, one Codex re-review.

## Loop cap and completion

- Maximum **2 total cycles**. Unresolved after that → user decides; record the override, rationale, and the dissenting finding in the ledger/PR description.
- A gate passes when: internal review clean (≥80-confidence findings fixed), Codex verdict `approve` (or documented user override), tests green with captured output, and the human confirms the merge. Merges are always human-confirmed.

## Security

- Redact credentials/secrets from every input file before they enter the package (grep the diff for key patterns first: `API_KEY`, `SECRET`, `PASSWORD`, tokens).
- Codex is read-only, never merge-authorized, never orchestration-authorized.
