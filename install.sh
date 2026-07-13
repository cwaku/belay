#!/usr/bin/env bash
# Belay's plain-copy installer: puts the four skills in ~/.claude/skills for
# setups that skip the plugin marketplace route.
# Prefer the plugin install (see README) — don't use both on one machine,
# or every skill registers twice.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude/skills"
mkdir -p "$DEST"

echo "Roping up — installing Belay's four skills to ${DEST}"
echo

for skill in task-router codex-plan-review codex-gate-review handoff-checkpoint; do
  rm -rf "${DEST:?}/${skill}"
  cp -r "${SRC}/plugin/skills/${skill}" "${DEST}/${skill}"
  echo "  ✓ ${skill}"
done

# The global CLAUDE.md makes Belay instruction-strength in every session.
# Never overwrite an existing one — that file is yours.
GLOBAL_MD="${HOME}/.claude/CLAUDE.md"
echo
if [ ! -f "$GLOBAL_MD" ]; then
  cp "${SRC}/templates/CLAUDE.md" "$GLOBAL_MD"
  echo "  ✓ global CLAUDE.md — Belay now applies in every session"
else
  echo "  • You already have ${GLOBAL_MD} — I won't touch it."
  echo "    Merge the bullets from templates/CLAUDE.md into it yourself"
  echo "    so Belay applies in every session, not just when skills trigger."
fi

echo
echo "You're on belay. Start a new Claude Code session to pick up the skills."
echo "One more thing: the two review skills use the Codex CLI — run 'codex login'"
echo "when you get a chance. Without it they fall back to internal review; nothing blocks."
