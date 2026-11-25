---
name: codex-gate-review
description: Use at phase gates on T1 projects and for L4 tasks on T1 and T2 projects, independent Codex completion review of the branch diff, test output, and acceptance criteria before merge. Dual sign-off instrument; not for per-task use.
---

# Codex Gate Review

Second, independent sign-off at **phase gates** (T1) and **L4 tasks** (T1 and T2). Runs alongside, never instead of, the internal `/code-review` pass. Do not run per-task on L1 to L3; evidence shows per-task dual review adds latency, not defect yield.

## Evidence package (primary evidence, never summaries)

Build before invoking Codex:
1. `git diff <base>...<branch> > /tmp/gate-review.diff` (the actual diff, not a description)
2. Executed test output (run the suite; capture real output, "tests pass" claims are not evidence)
3. The acceptance criteria from the approved plan
4. For L4: the production-shape/verification transcript if the project has one

## Procedure

```bash
# FAMILY and EFFORT come from the table below.
# Newest model of that family that this CLI knows about, looked up at run time so no version is written here.
CODEX_MODEL=$(jq -r --arg fam "$FAMILY" '[.models[].slug | select(test("^gpt-[0-9.]+-" + $fam + "$"))] | sort_by(capture("^gpt-(?<v>[0-9.]+)-").v | split(".") | map(tonumber)) | last // empty' ~/.codex/models_cache.json 2>/dev/null)
# timeout is GNU coreutils and Homebrew installs it as gtimeout. With neither, the call runs with no cap.
TIMEOUT=$(command -v timeout || command -v gtimeout)
${TIMEOUT:+"$TIMEOUT" 20m} codex exec ${CODEX_MODEL:+-m "$CODEX_MODEL"} --sandbox read-only -c model_reasoning_effort="$EFFORT" --cd "$REPO" "You are the independent completion reviewer. Inputs: diff at /tmp/gate-review.diff, test log at <path>, acceptance criteria: <criteria>. Review for: correctness, completeness vs the criteria, code quality, architecture, security, test coverage, regression risk, and compliance with the approved plan. Inspect the diff and the codebase directly, do not trust any summary. Respond with ONLY this JSON: {\"verdict\": \"approve\"|\"blocked\", \"findings\": [{\"severity\": \"blocking\"|\"advisory\", \"claim\": \"...\", \"evidence\": \"file:line\", \"criterion\": \"which acceptance criterion this affects, if any\"}]}. Blocking ONLY for correctness defects, unmet criteria, security exposure, or silent-in-production failure modes." < /dev/null
```

Always close stdin (`< /dev/null`) and keep the 20 minute cap. A background `codex exec` with stdin left open waits on it and never starts. Exit status 124 means the timeout fired: treat it as a Codex outage, retry once, then degrade to internal review with a ledger note. `TIMEOUT` comes back empty on a machine with neither `timeout` nor `gtimeout`. The review still runs, with no cap: note that in the ledger.

| Run | `FAMILY` | `EFFORT` |
|-----|----------|----------|
| First pass of a gate | `astra` | `high`, or `xhigh` for an L4 task or a gate that covers a surface on the project's `l4-examples` line |
| Re-review after a fix wave or a rebuttal | `sol` | `high` at every level, L4 included |

Astra costs more of the Codex usage window per token than Sol (about double in the one comparison on record), so it runs once per gate, on the pass that reads the whole diff. The re-review checks the fixes against the first pass's findings.

The first pass has no cheaper tier: this skill only fires where risk already justified it. If latency or usage matters, the lever is whether the gate runs (task-router's ladder), never how hard the first pass thinks.

`CODEX_MODEL` resolves to the newest model of the chosen family in the CLI's own model list. If it comes back empty (no cache yet, or no model of that family on this account), the `-m` flag drops out and Codex uses its configured default: note that in the ledger. Never write a versioned model name into this skill, a plan or a brief.

- Parse JSON; retry once on malformed output; then degrade to internal-review-only with a ledger note. Codex outage never blocks shipping.
- **Verify each blocking finding against the code before acting.** Confirmed → fix wave, routed per task-router. Refuted → one written rebuttal with evidence, one Codex re-review.

## Loop cap and completion

A pass is one Codex run on the gate. After each pass, once its blocking findings are checked against the code, take the first row that matches:

| After pass N | Next |
|--------------|------|
| Codex raised again a blocking finding it already got a written rebuttal for | Stop. The user decides |
| Verdict `approve` | Codex is done. The gate still has to meet the last line of this section |
| N is 2 or more, and this pass has as many confirmed blocking findings as pass N-1, or more | Stop. The user decides |
| N is 4 | Stop. The user decides |
| None of the above | Fix wave for the confirmed findings, a rebuttal for the refuted ones, then pass N+1 |

Passes 3 and 4 are for gates where each pass finds fewer real defects than the one before. A finding that comes back after a rebuttal is a disagreement, and another pass will not settle it.

- On a stop, present both positions with evidence. Record the user's override, the rationale, the findings still open and the number of confirmed blocking findings in each pass in the ledger/PR description. Never run a fifth pass.
- A gate passes when: internal review clean (≥80-confidence findings fixed), Codex verdict `approve` (or documented user override), tests green with captured output, and the human confirms the merge. Merges are always human-confirmed.

## Security

- Redact credentials/secrets from every input file before they enter the package (grep the diff for key patterns first: `API_KEY`, `SECRET`, `PASSWORD`, tokens).
- Codex is read-only, never merge-authorized, never orchestration-authorized.
