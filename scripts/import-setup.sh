#!/usr/bin/env bash
# Interactive import of a setup exported by export-setup.sh: pick which
# plugins and skills to install, with recommendations for the ones that pair
# with Belay. Merges chosen plugin config into ~/.claude/settings.json
# (backup taken), copies chosen skills, installs global CLAUDE.md if absent.
#
# Flags:
#   --all           install everything without prompting
#   --recommended   install only the recommended plugins (+ all skills) without prompting
#   --from DIR      read the setup from DIR (e.g. a cloned dotfiles repo)
#                   instead of ./my-setup
set -euo pipefail

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="${HOME}/.claude/settings.json"

# Plugins that pair with Belay (matched on the part before '@'):
#   superpowers, plan-execution discipline the router hooks into
#   claude-mem , cross-session memory; checkpoints benefit from recall
#   code-review, the internal review pass the Codex gate runs alongside
RECOMMENDED=(superpowers claude-mem code-review)

MODE="interactive"
SRC="${ROOT}/my-setup"
while [ $# -gt 0 ]; do
  case "$1" in
    --all) MODE="all" ;;
    --recommended) MODE="recommended" ;;
    --from) SRC="$(cd "$2" && pwd)"; shift ;;
    *) echo "usage: $0 [--all|--recommended] [--from DIR]"; exit 1 ;;
  esac
  shift
done

[ -d "$SRC" ] || { echo "no setup found at ${SRC}, run export-setup.sh on the source machine first, or pass --from DIR"; exit 1; }

if [ "$MODE" = "interactive" ] && [ ! -t 0 ]; then
  echo "No TTY for prompts. Re-run with --all or --recommended."
  exit 1
fi

is_recommended() {
  local base="${1%%@*}"
  for r in "${RECOMMENDED[@]}"; do [ "$base" = "$r" ] && return 0; done
  return 1
}

ask() { # ask "<prompt>" <default y|n>
  local reply
  read -r -p "$1 " reply
  reply="${reply:-$2}"
  [[ "$reply" =~ ^[Yy] ]]
}

# --- 1. Choose plugins -------------------------------------------------------
CHOSEN_PLUGINS=()
if [ -f "${SRC}/plugins.json" ]; then
  echo "── Plugins ──────────────────────────────────────────"
  while IFS= read -r key; do
    # only offer plugins that were enabled on the source machine
    enabled=$(jq -r --arg k "$key" '.enabledPlugins[$k]' "${SRC}/plugins.json")
    [ "$enabled" = "true" ] || continue
    tag=""
    def="n"
    if is_recommended "$key"; then tag="  [recommended, pairs with Belay]"; def="y"; fi
    case "$MODE" in
      all) CHOSEN_PLUGINS+=("$key"); echo "  + ${key}${tag}" ;;
      recommended) if [ "$def" = "y" ]; then CHOSEN_PLUGINS+=("$key"); echo "  + ${key}${tag}"; fi ;;
      interactive)
        if ask "  ${key}${tag}, install? [${def^}/$([ "$def" = y ] && echo n || echo y)]" "$def"; then
          CHOSEN_PLUGINS+=("$key")
        fi ;;
    esac
  done < <(jq -r '.enabledPlugins | keys[]' "${SRC}/plugins.json")
fi

# --- 2. Merge chosen plugins + only the marketplaces they need ---------------
if [ "${#CHOSEN_PLUGINS[@]}" -gt 0 ]; then
  mkdir -p "${HOME}/.claude"
  FRAGMENT=$(jq --args '
    {enabledPlugins: (.enabledPlugins | with_entries(select(.key as $k | $ARGS.positional | index($k)))),
     extraKnownMarketplaces: (
       .extraKnownMarketplaces // {} | with_entries(
         select(.key as $m | $ARGS.positional | map(split("@")[1]) | index($m))))}
  ' "${CHOSEN_PLUGINS[@]}" < "${SRC}/plugins.json")
  [ -n "$FRAGMENT" ] || { echo "ERROR: failed to build plugin fragment"; exit 1; }
  if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "${SETTINGS}.bak.$(date +%s)"
    jq -s '.[0] * .[1]' "$SETTINGS" <(printf '%s' "$FRAGMENT") > "${SETTINGS}.tmp" \
      && mv "${SETTINGS}.tmp" "$SETTINGS"
    echo "merged ${#CHOSEN_PLUGINS[@]} plugin(s) into ${SETTINGS} (backup written)"
  else
    printf '%s\n' "$FRAGMENT" > "$SETTINGS"
    echo "created ${SETTINGS} with ${#CHOSEN_PLUGINS[@]} plugin(s)"
  fi
  # Warn about plugins whose marketplace isn't declared in settings (it was
  # added interactively on the source machine), they need one manual step.
  for key in "${CHOSEN_PLUGINS[@]}"; do
    mp="${key#*@}"
    [ "$mp" = "claude-plugins-official" ] && continue
    if ! jq -e --arg m "$mp" '.extraKnownMarketplaces[$m]' "${SRC}/plugins.json" >/dev/null; then
      echo "  ! ${key}: marketplace '${mp}' not in exported settings."
      echo "    run: /plugin marketplace add <owner>/<repo for ${mp}>  then  /plugin install ${key}"
    fi
  done
else
  echo "no plugins selected"
fi

# --- 3. Choose skills ---------------------------------------------------------
if [ -d "${SRC}/skills" ]; then
  echo "── Skills ───────────────────────────────────────────"
  mkdir -p "${HOME}/.claude/skills"
  for dir in "${SRC}/skills"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    if [ -d "${HOME}/.claude/skills/${name}" ]; then
      echo "  = ${name} already present, skipped"
      continue
    fi
    if [ "$MODE" = "interactive" ]; then
      ask "  skill ${name}, install? [Y/n]" "y" || continue
    fi
    cp -r "$dir" "${HOME}/.claude/skills/${name}"
    echo "  + installed ${name}"
  done
fi

# --- 4. Global CLAUDE.md, never overwrite ------------------------------------
if [ -f "${SRC}/CLAUDE.md" ] && [ ! -f "${HOME}/.claude/CLAUDE.md" ]; then
  cp "${SRC}/CLAUDE.md" "${HOME}/.claude/CLAUDE.md"
  echo "installed global CLAUDE.md"
fi

echo
echo "Done. Start Claude Code, it fetches declared marketplaces on launch."
echo "If a plugin doesn't activate automatically:"
echo "  /plugin marketplace add <marketplace>   then   /plugin install <name>@<marketplace>"
