#!/usr/bin/env bash
# Import a setup exported by export-setup.sh into this machine's Claude Code:
# merges plugin config into ~/.claude/settings.json (backup taken), copies
# personal skills, installs global CLAUDE.md if absent. Idempotent.
set -euo pipefail

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/my-setup"
SETTINGS="${HOME}/.claude/settings.json"

[ -d "$SRC" ] || { echo "no my-setup/ found — run export-setup.sh on the source machine first"; exit 1; }

# 1. Merge plugin config (existing local entries win on conflict).
if [ -f "${SRC}/plugins.json" ]; then
  mkdir -p "${HOME}/.claude"
  if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%s)"
    jq -s '.[1] * .[0]' "$SETTINGS" "${SRC}/plugins.json" > "${SETTINGS}.tmp" \
      && mv "${SETTINGS}.tmp" "$SETTINGS"
    echo "merged plugin config into ${SETTINGS} (backup written)"
  else
    jq '.' "${SRC}/plugins.json" > "$SETTINGS"
    echo "created ${SETTINGS} from plugin config"
  fi
  echo "Plugins declared:"
  jq -r '.enabledPlugins | keys[]' "${SRC}/plugins.json" | sed 's/^/  - /'
fi

# 2. Personal skills (never overwrites an existing skill of the same name).
if [ -d "${SRC}/skills" ]; then
  mkdir -p "${HOME}/.claude/skills"
  for dir in "${SRC}/skills"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    if [ -d "${HOME}/.claude/skills/${name}" ]; then
      echo "skill ${name} already present — skipped"
    else
      cp -r "$dir" "${HOME}/.claude/skills/${name}"
      echo "installed skill ${name}"
    fi
  done
fi

# 3. Global CLAUDE.md — never overwrite.
if [ -f "${SRC}/CLAUDE.md" ] && [ ! -f "${HOME}/.claude/CLAUDE.md" ]; then
  cp "${SRC}/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
  echo "installed global CLAUDE.md"
fi

echo
echo "Done. Start Claude Code — it fetches the declared marketplaces on launch."
echo "If any plugin doesn't activate automatically, install it interactively:"
echo "  /plugin marketplace add <marketplace>   then   /plugin install <name>@<marketplace>"
echo "using the list printed above."
