#!/usr/bin/env bash
# Fallback installer: copies the skills to ~/.claude/skills for environments
# where you don't want the plugin marketplace route.
# Prefer the plugin install (see README) — don't use both on one machine,
# or the skills will appear twice.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.claude/skills"
mkdir -p "$DEST"

for skill in task-router codex-plan-review codex-gate-review handoff-checkpoint; do
  rm -rf "${DEST:?}/${skill}"
  cp -r "${SRC}/plugin/skills/${skill}" "${DEST}/${skill}"
  echo "installed ${skill} -> ${DEST}/${skill}"
done

# Global CLAUDE.md makes the workflow instruction-strength in every session.
# Never overwrite an existing one — that file is personal.
GLOBAL_MD="${HOME}/.claude/CLAUDE.md"
if [ ! -f "$GLOBAL_MD" ]; then
  cp "${SRC}/templates/CLAUDE.md" "$GLOBAL_MD"
  echo "installed global CLAUDE.md -> ${GLOBAL_MD}"
else
  echo "NOTE: ${GLOBAL_MD} already exists — not touched."
  echo "      Merge templates/CLAUDE.md into it manually to make the workflow"
  echo "      instruction-strength in every session."
fi

echo "Done. Restart Claude Code (or start a new session) to pick up the skills."
echo "Optional: the two review skills use the Codex CLI (codex login); they degrade gracefully without it."
