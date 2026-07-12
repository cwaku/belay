#!/usr/bin/env bash
# Fallback installer: copies the skills to ~/.claude/skills for environments
# where you don't want the plugin marketplace route.
# Prefer the plugin install (see README) — don't use both on one machine,
# or the skills will appear twice.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plugin/skills"
DEST="${HOME}/.claude/skills"
mkdir -p "$DEST"

for skill in task-router codex-plan-review codex-gate-review handoff-checkpoint; do
  rm -rf "${DEST:?}/${skill}"
  cp -r "${SRC}/${skill}" "${DEST}/${skill}"
  echo "installed ${skill} -> ${DEST}/${skill}"
done

echo "Done. Restart Claude Code (or start a new session) to pick up the skills."
echo "Optional: codex CLI is required for the two review skills (they degrade gracefully without it)."
