#!/usr/bin/env bash
# Export this machine's wider Claude Code setup (plugins + personal skills +
# global CLAUDE.md) into my-setup/ so import-setup.sh can replicate it on
# another machine. my-setup/ is gitignored — your setup stays out of the repo
# unless you deliberately commit it (e.g. on a private fork).
set -euo pipefail

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/my-setup"
SETTINGS="${HOME}/.claude/settings.json"
KIT_SKILLS=(task-router codex-plan-review codex-gate-review handoff-checkpoint)

mkdir -p "${OUT}/skills"

# 1. Plugin configuration (marketplaces + which plugins are enabled).
if [ -f "$SETTINGS" ]; then
  jq '{enabledPlugins: (.enabledPlugins // {}), extraKnownMarketplaces: (.extraKnownMarketplaces // {})}' \
    "$SETTINGS" > "${OUT}/plugins.json"
  echo "exported plugin config -> my-setup/plugins.json"
else
  echo '{"enabledPlugins":{},"extraKnownMarketplaces":{}}' > "${OUT}/plugins.json"
  echo "no ${SETTINGS} found; wrote empty plugin config"
fi

# 2. Personal skills (everything in ~/.claude/skills except the kit's own —
#    those are managed by install.sh / the plugin).
for dir in "${HOME}/.claude/skills"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  skip=false
  for k in "${KIT_SKILLS[@]}"; do [ "$name" = "$k" ] && skip=true; done
  $skip && continue
  rm -rf "${OUT}/skills/${name}"
  cp -r "$dir" "${OUT}/skills/${name}"
  echo "exported skill ${name}"
done

# 3. Global CLAUDE.md, if present.
if [ -f "${HOME}/.claude/CLAUDE.md" ]; then
  cp "${HOME}/.claude/CLAUDE.md" "${OUT}/CLAUDE.md"
  echo "exported global CLAUDE.md"
fi

echo
echo "Done. Copy my-setup/ to the new machine (or keep it on a private fork)"
echo "and run scripts/import-setup.sh there."
echo "NOTE: plugin *data* does not transfer — e.g. claude-mem's memory database"
echo "stays on this machine; only the plugin installation carries over."
