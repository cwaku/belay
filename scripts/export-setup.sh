#!/usr/bin/env bash
# Export this machine's wider Claude Code setup (plugins + personal skills +
# global CLAUDE.md) into my-setup/ so import-setup.sh can replicate it on
# another machine. my-setup/ is gitignored, your setup stays out of the repo
# unless you deliberately commit it (e.g. on a private fork).
set -euo pipefail

# jq is required. Detect the system package manager and install it if missing.
ensure_jq() {
  command -v jq >/dev/null && return

  echo "jq is not installed; attempting to install it..."
  local sudo=""
  if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null; then sudo="sudo"; fi

  set +e
  if   command -v apt-get >/dev/null; then $sudo apt-get update && $sudo apt-get install -y jq
  elif command -v pacman  >/dev/null; then $sudo pacman -Sy --noconfirm jq
  elif command -v dnf     >/dev/null; then $sudo dnf install -y jq
  elif command -v yum     >/dev/null; then $sudo yum install -y jq
  elif command -v zypper  >/dev/null; then $sudo zypper --non-interactive install jq
  elif command -v apk     >/dev/null; then $sudo apk add jq
  elif command -v brew    >/dev/null; then brew install jq
  else
    echo "no supported package manager found. Install jq manually, then re-run."
    exit 1
  fi
  set -e

  command -v jq >/dev/null || { echo "jq install failed. Install it manually, then re-run."; exit 1; }
  echo "jq installed."
}
ensure_jq

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/my-setup"
SETTINGS="${HOME}/.claude/settings.json"
KIT_SKILLS=(task-router codex-plan-review codex-gate-review handoff-checkpoint)
# Extra skills to leave out of the export (space-separated), e.g. skills your
# OS or another installer manages per-machine: EXPORT_SKIP="omarchy" ./export-setup.sh
# Guard the append: expanding an empty array under `set -u` errors on bash 3.2.
if [ -n "${EXPORT_SKIP:-}" ]; then
  read -ra SKIP_SKILLS <<< "$EXPORT_SKIP"
  KIT_SKILLS+=("${SKIP_SKILLS[@]}")
fi

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

# 2. Personal skills (everything in ~/.claude/skills except Belay's own;
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
echo "NOTE: plugin *data* does not transfer, e.g. claude-mem's memory database"
echo "stays on this machine; only the plugin installation carries over."
