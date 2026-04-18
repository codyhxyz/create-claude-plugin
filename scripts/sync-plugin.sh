#!/usr/bin/env bash
# sync-plugin.sh — push plugin.json metadata to marketplace entries + GitHub repo.
#
# plugin.json is the source of truth. This script propagates structured,
# non-identity fields to everywhere they're mirrored:
#
#   marketplace.json entries (matched by .name == plugin.json.name):
#     description, homepage, repository, license, keywords,
#     source.repo (if source is a github object — derived from .repository slug)
#
#   GitHub repo metadata (via `gh repo edit`):
#     description, homepage, topics (add missing keywords by default;
#     --strict-topics replaces the full set)
#
# Does NOT change identity: plugin name, directory basename, repo slug. For
# renames use rename-plugin.sh. Does NOT touch README / CHANGELOG / prose —
# those are freeform. check-drift.sh is the companion detector: run it to
# find out what's out of sync, run this to fix it.
#
# Usage:
#   ./sync-plugin.sh <plugin-dir> [--dry-run] [--marketplace <path>] [--no-gh] [--strict-topics]
#
# Flags:
#   --dry-run         Plan only.
#   --marketplace <p> Also sync to an external marketplace.json (additive to
#                     the plugin's own .claude-plugin/marketplace.json).
#   --no-gh           Skip `gh repo edit`.
#   --strict-topics   Replace the full topic set instead of adding missing.
#
# Exit: 0 on success or dry-run, 1 on runtime error, 2 on usage error.
# Prereqs: jq; gh (unless --no-gh).

set -euo pipefail

PLUGIN_DIR=""
DRY_RUN=""
EXT_MARKETPLACE=""
NO_GH=""
STRICT_TOPICS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)         DRY_RUN=1; shift ;;
    --marketplace)     EXT_MARKETPLACE="${2:-}"; shift 2 ;;
    --no-gh)           NO_GH=1; shift ;;
    --strict-topics)   STRICT_TOPICS=1; shift ;;
    --help|-h)         echo "Usage: $0 <plugin-dir> [--dry-run] [--marketplace <path>] [--no-gh] [--strict-topics]"; exit 0 ;;
    -*)                echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
    *)
      if [[ -z "$PLUGIN_DIR" ]]; then PLUGIN_DIR="$1"
      else echo "ERROR: unexpected positional '$1'" >&2; exit 2
      fi
      shift ;;
  esac
done

[[ -n "$PLUGIN_DIR" ]] || { echo "Usage: $0 <plugin-dir> [flags]" >&2; exit 2; }
[[ -d "$PLUGIN_DIR" ]] || { echo "ERROR: '$PLUGIN_DIR' is not a directory" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 2; }

PLUGIN_DIR=$(cd "$PLUGIN_DIR" && pwd)
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
SELF_MARKET="$PLUGIN_DIR/.claude-plugin/marketplace.json"
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }

if [[ -n "$EXT_MARKETPLACE" ]]; then
  [[ -f "$EXT_MARKETPLACE" ]] || { echo "ERROR: --marketplace path '$EXT_MARKETPLACE' not found" >&2; exit 2; }
  EXT_MARKETPLACE=$(cd "$(dirname "$EXT_MARKETPLACE")" && pwd)/$(basename "$EXT_MARKETPLACE")
fi

if [[ -t 1 ]]; then
  G=$'\033[32m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; Y=""; D=""; B=""; N=""
fi

# ---- Read plugin.json (source of truth) ----
P_NAME=$(jq -r '.name // ""'        "$MANIFEST")
P_DESC=$(jq -r '.description // ""' "$MANIFEST")
P_HOME=$(jq -r '.homepage // ""'    "$MANIFEST")
P_REPO=$(jq -r '.repository // ""'  "$MANIFEST")
P_LIC=$( jq -r '.license // ""'     "$MANIFEST")
P_KW=$(  jq -c '.keywords // []'    "$MANIFEST")

[[ -n "$P_NAME" ]] || { echo "ERROR: plugin.json has no 'name'" >&2; exit 1; }

to_slug() {
  echo "$1" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git/?$##; s#^/+##; s#/+$##'
}
P_SLUG=$(to_slug "$P_REPO")

printf '%s==>%s Sync from plugin.json: %s%s%s\n' "$B" "$N" "$G" "$P_NAME" "$N"
printf '    %splugin.json:%s %s\n' "$D" "$N" "$MANIFEST"
[[ -n "$DRY_RUN" ]] && printf '    %smode:%s dry-run\n' "$D" "$N"
echo

CHANGES=0
note() { CHANGES=$((CHANGES+1)); printf '  %s•%s %s\n' "$B" "$N" "$*"; }

# ---- Per-marketplace diff & plan ----
# Returns 0 if changes planned for this file, 1 if nothing to do / not applicable.
# Also prints the plan lines.
plan_market() {
  local mfile="$1" label="$2"
  local matches
  matches=$(jq --arg n "$P_NAME" '[.plugins[]? | select(.name == $n)] | length' "$mfile")
  if [[ "$matches" -eq 0 ]]; then
    printf '  %s!%s %s: no entry matches plugin.json name %s — is the name wrong, or did you mean to run rename-plugin.sh?\n' "$Y" "$N" "$label" "$P_NAME"
    return 1
  fi
  local entry cur_desc cur_home cur_repo cur_lic cur_kw cur_src_type cur_src_repo
  entry=$(jq -c --arg n "$P_NAME" '.plugins[] | select(.name == $n)' "$mfile")
  cur_desc=$(echo     "$entry" | jq -r '.description // ""')
  cur_home=$(echo     "$entry" | jq -r '.homepage // ""')
  cur_repo=$(echo     "$entry" | jq -r '.repository // ""')
  cur_lic=$(echo      "$entry" | jq -r '.license // ""')
  cur_kw=$(echo       "$entry" | jq -c '.keywords // []')
  cur_src_type=$(echo "$entry" | jq -r '.source | type')
  cur_src_repo=$(echo "$entry" | jq -r 'if (.source | type) == "object" then (.source.repo // "") else "" end')

  local field_changes=0
  if [[ -n "$P_DESC" && "$cur_desc" != "$P_DESC" ]]; then
    note "$label: description ← plugin.json"; field_changes=$((field_changes+1))
  fi
  if [[ -n "$P_HOME" && "$cur_home" != "$P_HOME" ]]; then
    note "$label: homepage → $P_HOME"; field_changes=$((field_changes+1))
  fi
  if [[ -n "$P_REPO" && "$cur_repo" != "$P_REPO" ]]; then
    note "$label: repository → $P_REPO"; field_changes=$((field_changes+1))
  fi
  if [[ -n "$P_LIC" && "$cur_lic" != "$P_LIC" ]]; then
    note "$label: license → $P_LIC"; field_changes=$((field_changes+1))
  fi
  if [[ "$(echo "$cur_kw" | jq -c 'sort')" != "$(echo "$P_KW" | jq -c 'sort')" ]]; then
    note "$label: keywords → [$(echo "$P_KW" | jq -r 'join(", ")')]"; field_changes=$((field_changes+1))
  fi
  if [[ "$cur_src_type" == "object" && -n "$P_SLUG" && "$cur_src_repo" != "$P_SLUG" ]]; then
    note "$label: source.repo → $P_SLUG"; field_changes=$((field_changes+1))
  fi
  if [[ "$field_changes" -eq 0 ]]; then
    printf '  %s✓%s %s: already in sync\n' "$G" "$N" "$label"
    return 1
  fi
  return 0
}

apply_market() {
  local mfile="$1"
  local tmp; tmp=$(mktemp "$mfile.XXXXXX")
  jq --indent 2 \
    --arg pname "$P_NAME" \
    --arg pdesc "$P_DESC" \
    --arg phome "$P_HOME" \
    --arg prepo "$P_REPO" \
    --arg plic  "$P_LIC" \
    --argjson pkw "$P_KW" \
    --arg pslug "$P_SLUG" '
    .plugins |= map(
      if .name == $pname then
        (if $pdesc != "" then .description = $pdesc else . end)
        | (if $phome != "" then .homepage   = $phome else . end)
        | (if $prepo != "" then .repository = $prepo else . end)
        | (if $plic  != "" then .license    = $plic  else . end)
        | .keywords = $pkw
        | (if (.source | type) == "object" and (.source.source // "") == "github" and $pslug != "" then .source.repo = $pslug else . end)
      else . end
    )
  ' "$mfile" > "$tmp"
  mv "$tmp" "$mfile"
}

printf '%sPlanned changes:%s\n' "$B" "$N"

SELF_SYNC=""
if [[ -f "$SELF_MARKET" ]]; then
  plan_market "$SELF_MARKET"   "self-marketplace"    && SELF_SYNC=1 || true
fi

EXT_SYNC=""
if [[ -n "$EXT_MARKETPLACE" ]]; then
  plan_market "$EXT_MARKETPLACE" "external marketplace" && EXT_SYNC=1 || true
fi

# ---- GitHub repo sync ----
GH_DESC_CHG=""; GH_HOME_CHG=""; GH_TOPICS_ADD=""; GH_TOPICS_SET=""
if [[ -z "$NO_GH" && -n "$P_SLUG" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    printf '  %s!%s gh CLI not installed; skipping gh sync (use --no-gh to silence)\n' "$Y" "$N"
  elif ! REPO_META=$(gh api "repos/$P_SLUG" 2>/dev/null); then
    printf '  %s!%s gh repo %s: could not fetch metadata (auth? private? renamed?); skipping gh sync\n' "$Y" "$N" "$P_SLUG"
  else
    GH_DESC=$(echo   "$REPO_META" | jq -r '.description // ""')
    GH_HOME=$(echo   "$REPO_META" | jq -r '.homepage // ""')
    GH_TOPICS=$(echo "$REPO_META" | jq -c '.topics // []')

    local_changes=0
    if [[ -n "$P_DESC" && "$GH_DESC" != "$P_DESC" ]]; then
      note "gh repo $P_SLUG: description ← plugin.json"
      GH_DESC_CHG=1; local_changes=$((local_changes+1))
    fi
    if [[ -n "$P_HOME" && "$GH_HOME" != "$P_HOME" ]]; then
      note "gh repo $P_SLUG: homepage → $P_HOME"
      GH_HOME_CHG=1; local_changes=$((local_changes+1))
    fi
    if [[ -n "$STRICT_TOPICS" ]]; then
      if [[ "$(echo "$GH_TOPICS" | jq -c 'sort')" != "$(echo "$P_KW" | jq -c 'sort')" ]]; then
        note "gh repo $P_SLUG: topics replace → [$(echo "$P_KW" | jq -r 'join(", ")')]"
        GH_TOPICS_SET=1; local_changes=$((local_changes+1))
      fi
    else
      MISSING=$(jq -cn --argjson k "$P_KW" --argjson t "$GH_TOPICS" '$k - $t')
      if [[ "$MISSING" != "[]" ]]; then
        note "gh repo $P_SLUG: add topics [$(echo "$MISSING" | jq -r 'join(", ")')]"
        GH_TOPICS_ADD="$MISSING"; local_changes=$((local_changes+1))
      fi
    fi
    if [[ "$local_changes" -eq 0 ]]; then
      printf '  %s✓%s gh repo %s: already in sync\n' "$G" "$N" "$P_SLUG"
    fi
  fi
fi

if [[ "$CHANGES" -eq 0 ]]; then
  echo
  echo "Everything already in sync. Nothing to do."
  exit 0
fi

if [[ -n "$DRY_RUN" ]]; then
  echo
  printf '%s==> Dry-run: no changes applied.%s\n' "$B" "$N"
  exit 0
fi

# ---- Apply ----
echo
printf '%s==> Applying...%s\n' "$B" "$N"

[[ -n "$SELF_SYNC" ]] && { apply_market "$SELF_MARKET";    printf '  %s✓%s updated %s\n' "$G" "$N" "$SELF_MARKET"; }
[[ -n "$EXT_SYNC"  ]] && { apply_market "$EXT_MARKETPLACE"; printf '  %s✓%s updated %s\n' "$G" "$N" "$EXT_MARKETPLACE"; }

if [[ -n "$GH_DESC_CHG" || -n "$GH_HOME_CHG" ]]; then
  args=()
  [[ -n "$GH_DESC_CHG" ]] && args+=(--description "$P_DESC")
  [[ -n "$GH_HOME_CHG" ]] && args+=(--homepage    "$P_HOME")
  if gh repo edit "$P_SLUG" "${args[@]}" >/dev/null 2>&1; then
    printf '  %s✓%s gh repo %s: description/homepage updated\n' "$G" "$N" "$P_SLUG"
  else
    printf '  %s!%s gh repo %s: edit failed\n' "$Y" "$N" "$P_SLUG"
  fi
fi

if [[ -n "$GH_TOPICS_ADD" ]]; then
  while IFS= read -r topic; do
    [[ -z "$topic" ]] && continue
    if gh repo edit "$P_SLUG" --add-topic "$topic" >/dev/null 2>&1; then
      printf '  %s✓%s gh repo %s: +topic %s\n' "$G" "$N" "$P_SLUG" "$topic"
    else
      printf '  %s!%s gh repo %s: failed to add topic %s\n' "$Y" "$N" "$P_SLUG" "$topic"
    fi
  done < <(echo "$GH_TOPICS_ADD" | jq -r '.[]')
fi

if [[ -n "$GH_TOPICS_SET" ]]; then
  # Full replace: PUT /repos/{slug}/topics with {"names": [...]}
  if echo "$P_KW" | jq '{names: .}' | gh api --method PUT "repos/$P_SLUG/topics" --input - >/dev/null 2>&1; then
    printf '  %s✓%s gh repo %s: topics replaced\n' "$G" "$N" "$P_SLUG"
  else
    printf '  %s!%s gh repo %s: topics replace failed\n' "$Y" "$N" "$P_SLUG"
  fi
fi

echo
printf '%s==> Done.%s Verify with check-drift.sh.\n' "$B" "$N"
