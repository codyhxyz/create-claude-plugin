#!/usr/bin/env bash
# check-drift.sh — three-way diff for plugin metadata across a marketplace.
#
# For each plugin listed in a marketplace.json, compares:
#   1. the marketplace entry
#   2. the plugin's own .claude-plugin/plugin.json (fetched from GitHub or read locally)
#   3. the actual GitHub repo metadata (full_name, html_url, description, topics, license)
#
# Reports drift. Does not fix. The human (or a rename script) resolves each
# finding — see ARCHITECTURE.md "Why check-submission.sh is the only script":
# this tool is the safety net, the rename script is the ergonomics layer.
#
# Usage:
#   ./check-drift.sh [<marketplace.json-or-dir>] [--offline] [--no-color] [--plugin <name>]
#
#   <marketplace.json-or-dir>  Path to marketplace.json, or a dir containing
#                              .claude-plugin/marketplace.json. Default: ".".
#   --offline                  Skip gh api calls. github-source plugins fall
#                              back to a sibling local checkout if one exists.
#   --no-color                 Disable ANSI color.
#   --plugin <name>            Limit checks to a single plugin by marketplace name.
#
# Exit: 0 if all clean, 1 if any drift or unreachable, 2 on usage error.
#
# Prereqs: jq; gh (optional; required unless --offline).

set -euo pipefail

MP_ARG="."
OFFLINE=""
NO_COLOR=""
ONLY_PLUGIN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)   OFFLINE=1; shift ;;
    --no-color)  NO_COLOR=1; shift ;;
    --plugin)    ONLY_PLUGIN="${2:-}"; shift 2 ;;
    --help|-h)   echo "Usage: $0 [<marketplace.json-or-dir>] [--offline] [--no-color] [--plugin <name>]"; exit 0 ;;
    -*)          echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
    *)           MP_ARG="$1"; shift ;;
  esac
done

if [[ -d "$MP_ARG" && -f "$MP_ARG/.claude-plugin/marketplace.json" ]]; then
  MP="$MP_ARG/.claude-plugin/marketplace.json"
elif [[ -f "$MP_ARG" ]]; then
  MP="$MP_ARG"
else
  echo "ERROR: no marketplace.json found at '$MP_ARG'" >&2; exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (brew install jq)" >&2; exit 2; }
jq empty "$MP" >/dev/null 2>&1 || { echo "ERROR: $MP is not valid JSON" >&2; exit 2; }

MP_ROOT=$(cd "$(dirname "$MP")/.." && pwd)

if [[ -z "$NO_COLOR" && -t 1 ]]; then
  G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; Y=""; R=""; D=""; B=""; N=""
fi

if [[ -z "$OFFLINE" ]] && ! command -v gh >/dev/null 2>&1; then
  echo "${Y}!${N} gh CLI not found — running in offline mode" >&2
  OFFLINE=1
fi

TOTAL=0; MATCH=0; DRIFT=0; UNREACHABLE=0
match()   { MATCH=$((MATCH+1));             printf '    %s✓%s %s\n' "$G" "$N" "$*"; }
drift()   { DRIFT=$((DRIFT+1));             printf '    %s⚠%s %s\n' "$Y" "$N" "$*"; }
unreach() { UNREACHABLE=$((UNREACHABLE+1)); printf '    %s✗%s %s\n' "$R" "$N" "$*"; }

# Diff two scalar strings. Labels name each side for the drift trace.
diff_scalar() {
  local field="$1" a_label="$2" a="$3" b_label="$4" b="$5"
  if [[ "$a" == "$b" ]]; then
    match "$field matches: ${a:-<empty>}"
  else
    drift "$field differs"
    printf '        %s%s:%s %s\n' "$D" "$a_label" "$N" "${a:-<empty>}"
    printf '        %s%s:%s %s\n' "$D" "$b_label" "$N" "${b:-<empty>}"
  fi
}

# Diff two JSON arrays order-insensitively. Reports set membership diff.
diff_array() {
  local field="$1" a_label="$2" a="$3" b_label="$4" b="$5"
  a=$(echo "${a:-[]}" | jq -c 'if . == null then [] else . end')
  b=$(echo "${b:-[]}" | jq -c 'if . == null then [] else . end')
  if [[ "$(echo "$a" | jq -c 'sort')" == "$(echo "$b" | jq -c 'sort')" ]]; then
    match "$field match ($(echo "$a" | jq 'length') entries)"
  else
    drift "$field differ"
    local only_a only_b
    only_a=$(jq -cn --argjson a "$a" --argjson b "$b" '$a - $b')
    only_b=$(jq -cn --argjson a "$a" --argjson b "$b" '$b - $a')
    [[ "$only_a" != "[]" ]] && printf '        %sonly in %s:%s %s\n' "$D" "$a_label" "$N" "$(echo "$only_a" | jq -r 'join(", ")')"
    [[ "$only_b" != "[]" ]] && printf '        %sonly in %s:%s %s\n' "$D" "$b_label" "$N" "$(echo "$only_b" | jq -r 'join(", ")')"
  fi
}

# Normalize a repo URL or slug into "owner/repo".
to_slug() {
  echo "$1" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git/?$##; s#^/+##; s#/+$##'
}

MP_NAME=$(jq -r '.name // "<unnamed>"' "$MP")
MP_PLUGIN_COUNT=$(jq -r '.plugins | length' "$MP")
printf '%s==> Marketplace:%s %s (%s plugin entries)\n' "$B" "$N" "$MP_NAME" "$MP_PLUGIN_COUNT"
printf '    %sfile:%s %s\n' "$D" "$N" "$MP"
[[ -n "$OFFLINE" ]] && printf '    %smode:%s offline (skipping gh api)\n' "$D" "$N"
echo

idx=0
while IFS= read -r entry; do
  idx=$((idx+1))
  MP_P_NAME=$(echo "$entry" | jq -r '.name // ""')
  [[ -n "$ONLY_PLUGIN" && "$MP_P_NAME" != "$ONLY_PLUGIN" ]] && continue
  TOTAL=$((TOTAL+1))

  MP_P_DESC=$(echo "$entry"     | jq -r '.description // ""')
  MP_P_HOMEPAGE=$(echo "$entry" | jq -r '.homepage // ""')
  MP_P_REPO=$(echo "$entry"     | jq -r '.repository // ""')
  MP_P_LICENSE=$(echo "$entry"  | jq -r '.license // ""')
  MP_P_KEYWORDS=$(echo "$entry" | jq -c '.keywords // []')
  SRC_RAW=$(echo "$entry"       | jq -c '.source // null')
  SRC_TYPE=$(echo "$SRC_RAW"    | jq -r 'if type == "string" then "path" elif type == "object" then (.source // "path") else "unknown" end')
  SRC_REPO=""; SRC_PATH=""
  case "$SRC_TYPE" in
    github) SRC_REPO=$(echo "$SRC_RAW" | jq -r '.repo // ""') ;;
    path)
      if [[ "$(echo "$SRC_RAW" | jq -r 'type')" == "string" ]]; then
        SRC_PATH=$(echo "$SRC_RAW" | jq -r '.')
      else
        SRC_PATH=$(echo "$SRC_RAW" | jq -r '.path // ""')
      fi
      ;;
  esac

  printf '%s==> [%s] %s%s\n' "$B" "$idx" "$MP_P_NAME" "$N"
  case "$SRC_TYPE" in
    github)  printf '    %ssource:%s github %s\n'  "$D" "$N" "$SRC_REPO" ;;
    path)    printf '    %ssource:%s path %s\n'    "$D" "$N" "$SRC_PATH" ;;
    *)       printf '    %ssource:%s %s\n'         "$D" "$N" "$SRC_TYPE" ;;
  esac

  # ---- Load plugin.json: prefer authoritative source on GitHub, fall back to sibling local checkout ----
  PLUGIN_JSON=""; PJ_VIA=""
  if [[ "$SRC_TYPE" == "github" && -n "$SRC_REPO" && -z "$OFFLINE" ]]; then
    if PJ=$(gh api -H "Accept: application/vnd.github.raw" "repos/$SRC_REPO/contents/.claude-plugin/plugin.json" 2>/dev/null) && [[ -n "$PJ" ]]; then
      PLUGIN_JSON="$PJ"; PJ_VIA="gh:$SRC_REPO"
    fi
  fi
  if [[ -z "$PLUGIN_JSON" && "$SRC_TYPE" == "github" && -n "$SRC_REPO" ]]; then
    cand="$MP_ROOT/../${SRC_REPO##*/}"
    if [[ -f "$cand/.claude-plugin/plugin.json" ]]; then
      PLUGIN_JSON=$(cat "$cand/.claude-plugin/plugin.json"); PJ_VIA="local:$cand"
    fi
  fi
  if [[ -z "$PLUGIN_JSON" && "$SRC_TYPE" == "path" && -n "$SRC_PATH" ]]; then
    resolved="$MP_ROOT/$SRC_PATH"
    if [[ -f "$resolved/.claude-plugin/plugin.json" ]]; then
      PLUGIN_JSON=$(cat "$resolved/.claude-plugin/plugin.json"); PJ_VIA="local:$resolved"
    fi
  fi

  if [[ -z "$PLUGIN_JSON" ]]; then
    unreach "plugin.json unreachable (offline with no local checkout, or repo private/renamed)"
    echo; continue
  fi
  if ! echo "$PLUGIN_JSON" | jq empty >/dev/null 2>&1; then
    unreach "plugin.json is not valid JSON"
    echo; continue
  fi
  printf '    %splugin.json via:%s %s\n' "$D" "$N" "$PJ_VIA"

  P_NAME=$(echo     "$PLUGIN_JSON" | jq -r '.name // ""')
  P_DESC=$(echo     "$PLUGIN_JSON" | jq -r '.description // ""')
  P_HOMEPAGE=$(echo "$PLUGIN_JSON" | jq -r '.homepage // ""')
  P_REPO=$(echo     "$PLUGIN_JSON" | jq -r '.repository // ""')
  P_LICENSE=$(echo  "$PLUGIN_JSON" | jq -r '.license // ""')
  P_KEYWORDS=$(echo "$PLUGIN_JSON" | jq -c '.keywords // []')

  printf '  %smarketplace ↔ plugin.json%s\n' "$B" "$N"
  diff_scalar "name"        "marketplace" "$MP_P_NAME"     "plugin.json" "$P_NAME"
  diff_scalar "description" "marketplace" "$MP_P_DESC"     "plugin.json" "$P_DESC"
  diff_scalar "homepage"    "marketplace" "$MP_P_HOMEPAGE" "plugin.json" "$P_HOMEPAGE"
  diff_scalar "repository"  "marketplace" "$MP_P_REPO"     "plugin.json" "$P_REPO"
  diff_scalar "license"     "marketplace" "$MP_P_LICENSE"  "plugin.json" "$P_LICENSE"
  diff_array  "keywords"    "marketplace" "$MP_P_KEYWORDS" "plugin.json" "$P_KEYWORDS"

  # ---- GitHub repo metadata ----
  if [[ "$SRC_TYPE" == "github" && -n "$SRC_REPO" && -z "$OFFLINE" ]]; then
    if REPO_META=$(gh api "repos/$SRC_REPO" 2>/dev/null); then
      printf '  %smarketplace ↔ GitHub (%s)%s\n' "$B" "$SRC_REPO" "$N"
      GH_FULL=$(echo     "$REPO_META" | jq -r '.full_name // ""')
      GH_URL=$(echo      "$REPO_META" | jq -r '.html_url // ""')
      GH_DESC=$(echo     "$REPO_META" | jq -r '.description // ""')
      GH_HOMEPAGE=$(echo "$REPO_META" | jq -r '.homepage // ""')
      GH_LICENSE=$(echo  "$REPO_META" | jq -r '.license.spdx_id // ""')
      GH_TOPICS=$(echo   "$REPO_META" | jq -c '.topics // []')

      diff_scalar "source.repo"     "marketplace" "$SRC_REPO"            "GitHub full_name" "$GH_FULL"
      diff_scalar "repository slug" "marketplace" "$(to_slug "$MP_P_REPO")" "GitHub full_name" "$GH_FULL"

      # Homepage: plugins commonly set homepage = repo URL. GitHub surfaces this as html_url.
      if [[ -n "$MP_P_HOMEPAGE" ]]; then
        if [[ "$MP_P_HOMEPAGE" == "$GH_URL" || "$MP_P_HOMEPAGE" == "$GH_HOMEPAGE" ]]; then
          match "homepage resolves to GitHub html_url or configured homepage"
        else
          drift "homepage does not match GitHub html_url or configured homepage"
          printf '        %smarketplace:%s %s\n'              "$D" "$N" "$MP_P_HOMEPAGE"
          printf '        %sGitHub html_url:%s %s\n'          "$D" "$N" "$GH_URL"
          printf '        %sGitHub homepage field:%s %s\n'    "$D" "$N" "${GH_HOMEPAGE:-<empty>}"
        fi
      fi

      # GitHub description: sync target, not authoritative. Flag if it matches nothing.
      if [[ -z "$GH_DESC" ]]; then
        drift "GitHub repo has no description set — sync from plugin.json via 'gh repo edit $SRC_REPO --description ...'"
      elif [[ "$GH_DESC" == "$MP_P_DESC" || "$GH_DESC" == "$P_DESC" ]]; then
        match "GitHub description matches marketplace or plugin.json"
      else
        drift "GitHub description differs from both marketplace and plugin.json"
        printf '        %sGitHub:%s %s\n'      "$D" "$N" "$GH_DESC"
        printf '        %smarketplace:%s %s\n' "$D" "$N" "$MP_P_DESC"
        printf '        %splugin.json:%s %s\n' "$D" "$N" "$P_DESC"
      fi

      if [[ -n "$GH_LICENSE" && "$GH_LICENSE" != "NOASSERTION" ]]; then
        diff_scalar "license SPDX id" "plugin.json" "$P_LICENSE" "GitHub" "$GH_LICENSE"
      fi

      # Topics may legitimately include tags beyond keywords; only flag MISSING ones.
      MISSING=$(jq -cn --argjson k "$P_KEYWORDS" --argjson t "$GH_TOPICS" '$k - $t')
      if [[ "$MISSING" == "[]" ]]; then
        match "all plugin.json keywords present in GitHub topics"
      else
        drift "GitHub topics missing keywords: $(echo "$MISSING" | jq -r 'join(", ")')"
      fi
    else
      unreach "could not fetch repo metadata for $SRC_REPO (private? renamed? gh auth?)"
    fi
  fi

  echo
done < <(jq -c '.plugins[]' "$MP")

printf '%s==> Summary%s\n' "$B" "$N"
printf '    %s plugin(s) checked\n' "$TOTAL"
printf '    %s%s match%s, %s%s drift finding(s)%s, %s%s unreachable%s\n' \
  "$G" "$MATCH" "$N" "$Y" "$DRIFT" "$N" "$R" "$UNREACHABLE" "$N"

[[ "$DRIFT" -gt 0 || "$UNREACHABLE" -gt 0 ]] && exit 1 || exit 0
