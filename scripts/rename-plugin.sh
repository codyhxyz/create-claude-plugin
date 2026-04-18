#!/usr/bin/env bash
# rename-plugin.sh — structured-field-only rename of a Claude Code plugin.
#
# Renames a plugin across structured fields only:
#   - directory name (if basename matches the old plugin name)
#   - .claude-plugin/plugin.json: name, homepage, repository
#   - plugin's own .claude-plugin/marketplace.json (if present):
#         top-level name (self-marketplace), plugin entries' name/homepage/
#         repository/source.repo
#   - external marketplace.json (via --marketplace <path>)
#   - GitHub repo + local git remote (optional, via --rename-gh-repo)
#
# Does NOT edit README / CHANGELOG / MARKETING / SKILL.md / AGENT.md or any
# freeform prose — those often deserve rewording, not mechanical substitution.
# Instead prints a grep hit list so the human can rewrite them. check-drift.sh
# is the companion safety net — run it after renaming to catch anything missed.
#
# Usage:
#   ./rename-plugin.sh <plugin-dir> <new-name> [--dry-run] [--marketplace <path>] [--rename-gh-repo]
#
# Flags:
#   --dry-run           Plan only. No file edits, no git ops, no directory move.
#   --marketplace <p>   Also update an external marketplace.json at this path
#                       (for multi-plugin marketplace repos). The plugin's own
#                       .claude-plugin/marketplace.json is always updated if
#                       present — this flag is additive.
#   --rename-gh-repo    Also run `gh repo rename <new>` and update the local
#                       git remote URL. Resolves slug from plugin.json's
#                       repository URL.
#
# Exit: 0 on success or dry-run, 1 on runtime error, 2 on usage error.
#
# Prereqs: jq; gh (only required with --rename-gh-repo).

set -euo pipefail

PLUGIN_DIR=""
NEW_NAME=""
DRY_RUN=""
EXT_MARKETPLACE=""
RENAME_GH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)         DRY_RUN=1; shift ;;
    --marketplace)     EXT_MARKETPLACE="${2:-}"; shift 2 ;;
    --rename-gh-repo)  RENAME_GH=1; shift ;;
    --help|-h)         echo "Usage: $0 <plugin-dir> <new-name> [--dry-run] [--marketplace <path>] [--rename-gh-repo]"; exit 0 ;;
    -*)                echo "ERROR: unknown flag '$1'" >&2; exit 2 ;;
    *)
      if [[ -z "$PLUGIN_DIR" ]]; then PLUGIN_DIR="$1"
      elif [[ -z "$NEW_NAME" ]]; then NEW_NAME="$1"
      else echo "ERROR: unexpected positional arg '$1'" >&2; exit 2
      fi
      shift ;;
  esac
done

if [[ -z "$PLUGIN_DIR" || -z "$NEW_NAME" ]]; then
  echo "Usage: $0 <plugin-dir> <new-name> [--dry-run] [--marketplace <path>] [--rename-gh-repo]" >&2
  exit 2
fi
[[ -d "$PLUGIN_DIR" ]] || { echo "ERROR: '$PLUGIN_DIR' is not a directory" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 2; }

if [[ ! "$NEW_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "ERROR: new name '$NEW_NAME' is not kebab-case" >&2; exit 2
fi

PLUGIN_DIR=$(cd "$PLUGIN_DIR" && pwd)
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
SELF_MARKET="$PLUGIN_DIR/.claude-plugin/marketplace.json"
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }

OLD_NAME=$(jq -r '.name // ""' "$MANIFEST")
[[ -n "$OLD_NAME" ]] || { echo "ERROR: plugin.json has no 'name' field" >&2; exit 1; }
if [[ "$OLD_NAME" == "$NEW_NAME" ]]; then
  echo "plugin.json name is already '$NEW_NAME' — nothing to do."; exit 0
fi
OLD_REPO_URL=$(jq -r '.repository // ""' "$MANIFEST")
OLD_HOMEPAGE=$(jq -r '.homepage // ""'   "$MANIFEST")
DIR_BASENAME=$(basename "$PLUGIN_DIR")

if [[ -n "$EXT_MARKETPLACE" ]]; then
  [[ -f "$EXT_MARKETPLACE" ]] || { echo "ERROR: --marketplace path '$EXT_MARKETPLACE' not found" >&2; exit 2; }
  EXT_MARKETPLACE=$(cd "$(dirname "$EXT_MARKETPLACE")" && pwd)/$(basename "$EXT_MARKETPLACE")
fi

if [[ -t 1 ]]; then
  G=$'\033[32m'; Y=$'\033[33m'; D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; Y=""; D=""; B=""; N=""
fi

# Rewrite a URL's trailing slug from OLD_NAME → NEW_NAME, but only if the
# URL's last path segment (optionally with a .git suffix) actually matches
# OLD_NAME. Returns the original URL if no match, so an unrelated homepage
# (e.g. a docs site) isn't mangled.
rewrite_url() {
  local url="$1"
  [[ -z "$url" ]] && { echo ""; return; }
  echo "$url" | sed -E "s#/${OLD_NAME}(\.git)?/?\$#/${NEW_NAME}\1#"
}

NEW_REPO_URL=$(rewrite_url "$OLD_REPO_URL")
NEW_HOMEPAGE=$(rewrite_url "$OLD_HOMEPAGE")

# Extract owner/repo slug from a GitHub URL (same regex as check-drift.sh).
to_slug() {
  echo "$1" | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git/?$##; s#^/+##; s#/+$##'
}
OLD_SLUG=$(to_slug "$OLD_REPO_URL")
OLD_OWNER="${OLD_SLUG%%/*}"
NEW_SLUG=""
if [[ -n "$OLD_OWNER" && "$OLD_SLUG" == */* ]]; then
  NEW_SLUG="$OLD_OWNER/$NEW_NAME"
fi

printf '%s==>%s Rename plan: %s%s%s → %s%s%s\n' "$B" "$N" "$Y" "$OLD_NAME" "$N" "$G" "$NEW_NAME" "$N"
printf '    %splugin dir:%s %s\n'  "$D" "$N" "$PLUGIN_DIR"
printf '    %sdir basename:%s %s\n' "$D" "$N" "$DIR_BASENAME"
[[ -n "$DRY_RUN" ]] && printf '    %smode:%s dry-run\n' "$D" "$N"
echo

# ---- Plan ----
PLAN=()
add_plan() { PLAN+=("$1"); printf '  %s•%s %s\n' "$B" "$N" "$1"; }

printf '%sPlanned structured changes:%s\n' "$B" "$N"

# plugin.json
JQ_EDITS=( '.name = $new' )
JQ_ARGS=( --arg new "$NEW_NAME" )
add_plan "plugin.json: name '$OLD_NAME' → '$NEW_NAME'"
if [[ -n "$OLD_REPO_URL" && "$NEW_REPO_URL" != "$OLD_REPO_URL" ]]; then
  JQ_EDITS+=( '.repository = $repo' ); JQ_ARGS+=( --arg repo "$NEW_REPO_URL" )
  add_plan "plugin.json: repository '$OLD_REPO_URL' → '$NEW_REPO_URL'"
elif [[ -n "$OLD_REPO_URL" ]]; then
  printf '  %s!%s plugin.json repository URL does not contain old name; left unchanged: %s\n' "$Y" "$N" "$OLD_REPO_URL"
fi
if [[ -n "$OLD_HOMEPAGE" && "$NEW_HOMEPAGE" != "$OLD_HOMEPAGE" ]]; then
  JQ_EDITS+=( '.homepage = $home' ); JQ_ARGS+=( --arg home "$NEW_HOMEPAGE" )
  add_plan "plugin.json: homepage '$OLD_HOMEPAGE' → '$NEW_HOMEPAGE'"
elif [[ -n "$OLD_HOMEPAGE" ]]; then
  printf '  %s!%s plugin.json homepage URL does not contain old name; left unchanged: %s\n' "$Y" "$N" "$OLD_HOMEPAGE"
fi

# Build the jq expression by joining edits with |
JQ_EXPR=$(printf '%s | ' "${JQ_EDITS[@]}"); JQ_EXPR="${JQ_EXPR% | }"

# Marketplace update helper: updates one marketplace.json file's matching
# plugin entry (identified by .name == OLD_NAME), plus top-level .name if
# it matches (single-plugin self-marketplace pattern). Echoes "skipped" if
# no matching entry so the caller can decide whether that's ok.
plan_market_edits() {
  local mfile="$1" label="$2"
  local found top_matches
  found=$(jq --arg old "$OLD_NAME" '[.plugins[]? | select(.name == $old)] | length' "$mfile")
  top_matches=$(jq --arg old "$OLD_NAME" '.name == $old' "$mfile")
  if [[ "$found" -eq 0 && "$top_matches" != "true" ]]; then
    printf '  %s!%s %s: no entry named %s and top-level name differs; left unchanged\n' "$Y" "$N" "$label" "$OLD_NAME"
    return 1
  fi
  [[ "$top_matches" == "true" ]] && add_plan "$label: top-level name '$OLD_NAME' → '$NEW_NAME'"
  [[ "$found" -gt 0 ]] && add_plan "$label: $found plugin entry/entries will update name, source.repo, homepage, repository"
  return 0
}

if [[ -f "$SELF_MARKET" ]]; then
  plan_market_edits "$SELF_MARKET" "self-marketplace (plugin repo)" || true
fi
if [[ -n "$EXT_MARKETPLACE" ]]; then
  plan_market_edits "$EXT_MARKETPLACE" "external marketplace: $EXT_MARKETPLACE" || true
fi

# Directory rename
NEW_DIR_PATH=""
if [[ "$DIR_BASENAME" == "$OLD_NAME" ]]; then
  NEW_DIR_PATH="$(dirname "$PLUGIN_DIR")/$NEW_NAME"
  if [[ -e "$NEW_DIR_PATH" ]]; then
    printf '  %s!%s directory rename blocked: %s already exists\n' "$Y" "$N" "$NEW_DIR_PATH"
    NEW_DIR_PATH=""
  else
    add_plan "directory: $PLUGIN_DIR → $NEW_DIR_PATH"
  fi
else
  printf '  %s!%s directory basename (%s) differs from plugin name (%s); leaving directory alone\n' "$Y" "$N" "$DIR_BASENAME" "$OLD_NAME"
fi

# gh repo rename + remote
if [[ -n "$RENAME_GH" ]]; then
  if [[ -z "$NEW_SLUG" ]]; then
    printf '  %s!%s --rename-gh-repo set but plugin.json repository is not a GitHub URL; skipping gh rename\n' "$Y" "$N"
    RENAME_GH=""
  else
    command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required for --rename-gh-repo" >&2; exit 2; }
    add_plan "gh repo: rename $OLD_SLUG → $NEW_SLUG and update local 'origin' remote"
  fi
fi

if [[ "${#PLAN[@]}" -eq 0 ]]; then
  echo
  echo "No structured changes planned. Nothing to do."
  exit 0
fi

if [[ -n "$DRY_RUN" ]]; then
  echo
  printf '%s==> Dry-run: no changes applied.%s\n' "$B" "$N"
  echo "    Re-run without --dry-run to apply."
  exit 0
fi

# ---- Apply ----
echo
printf '%s==> Applying changes...%s\n' "$B" "$N"

# Atomic per-file: jq → tmp → mv. `jq --indent 2` preserves the common 2-space
# style used by all plugin.json / marketplace.json examples in this ecosystem.
write_json() {
  local file="$1"; shift
  local tmp; tmp=$(mktemp "$file.XXXXXX")
  jq --indent 2 "$@" "$file" > "$tmp"
  mv "$tmp" "$file"
}

write_json "$MANIFEST" "${JQ_ARGS[@]}" "$JQ_EXPR"
printf '  %s✓%s updated %s\n' "$G" "$N" "$MANIFEST"

# For marketplace files: update top-level name (if matches) + each plugin entry
# (match by .name == OLD_NAME). Source rewrites: if source is an object with
# .source == "github", rewrite .repo. If source is a string (relative path),
# leave it alone — self-marketplace source stays "./".
apply_market_edits() {
  local mfile="$1"
  write_json "$mfile" \
    --arg old "$OLD_NAME" \
    --arg new "$NEW_NAME" \
    --arg new_repo "$NEW_REPO_URL" \
    --arg new_home "$NEW_HOMEPAGE" \
    --arg new_slug "$NEW_SLUG" '
    (if .name == $old then .name = $new else . end)
    | .plugins |= map(
        if .name == $old then
          .name = $new
          | (if (.repository // "") | test("/" + $old + "(\\.git)?/?$") then .repository |= sub("/" + $old + "(?<g>\\.git)?/?$"; "/" + $new + (.g // "")) else . end)
          | (if (.homepage   // "") | test("/" + $old + "(\\.git)?/?$") then .homepage   |= sub("/" + $old + "(?<g>\\.git)?/?$"; "/" + $new + (.g // "")) else . end)
          | (if (.source | type) == "object" and .source.source == "github" and $new_slug != "" then .source.repo = $new_slug else . end)
        else . end
      )
  '
  printf '  %s✓%s updated %s\n' "$G" "$N" "$mfile"
}

if [[ -f "$SELF_MARKET" ]]; then
  if jq -e --arg old "$OLD_NAME" '.name == $old or any(.plugins[]?; .name == $old)' "$SELF_MARKET" >/dev/null 2>&1; then
    apply_market_edits "$SELF_MARKET"
  fi
fi
if [[ -n "$EXT_MARKETPLACE" ]]; then
  if jq -e --arg old "$OLD_NAME" '.name == $old or any(.plugins[]?; .name == $old)' "$EXT_MARKETPLACE" >/dev/null 2>&1; then
    apply_market_edits "$EXT_MARKETPLACE"
  fi
fi

# gh rename + remote URL. Both are reversible (gh remembers the old URL as a
# redirect for a while; local remote is just a config line).
if [[ -n "$RENAME_GH" ]]; then
  if gh repo rename --repo "$OLD_SLUG" "$NEW_NAME" --yes >/dev/null 2>&1; then
    printf '  %s✓%s renamed GitHub repo %s → %s\n' "$G" "$N" "$OLD_SLUG" "$NEW_SLUG"
  else
    printf '  %s!%s gh repo rename failed (already renamed? no permission? not authed?)\n' "$Y" "$N"
  fi
  if git -C "$PLUGIN_DIR" remote get-url origin >/dev/null 2>&1; then
    CUR_REMOTE=$(git -C "$PLUGIN_DIR" remote get-url origin)
    NEW_REMOTE=$(rewrite_url "$CUR_REMOTE")
    if [[ "$NEW_REMOTE" != "$CUR_REMOTE" ]]; then
      git -C "$PLUGIN_DIR" remote set-url origin "$NEW_REMOTE"
      printf '  %s✓%s updated local origin remote: %s → %s\n' "$G" "$N" "$CUR_REMOTE" "$NEW_REMOTE"
    fi
  fi
fi

# Directory rename last — once we mv, subsequent paths we computed become stale.
FINAL_DIR="$PLUGIN_DIR"
if [[ -n "$NEW_DIR_PATH" ]]; then
  mv "$PLUGIN_DIR" "$NEW_DIR_PATH"
  FINAL_DIR="$NEW_DIR_PATH"
  printf '  %s✓%s moved directory → %s\n' "$G" "$N" "$NEW_DIR_PATH"
  if [[ "$PWD" == "$PLUGIN_DIR"* ]]; then
    printf '  %s!%s your current shell is still inside the old path. Run: %scd %s%s\n' "$Y" "$N" "$B" "$NEW_DIR_PATH" "$N"
  fi
fi

# ---- Freeform prose hit list ----
echo
printf '%s==>%s Freeform prose mentioning %s%s%s (NOT edited — rewrite by hand):\n' "$B" "$N" "$Y" "$OLD_NAME" "$N"
PROSE_PATTERNS=(
  "README.md" "CHANGELOG.md" "MARKETING.md" "CLAUDE.md" "ARCHITECTURE.md"
  "skills" "agents" "hooks" "docs" "marketing"
)
HIT_COUNT=0
for p in "${PROSE_PATTERNS[@]}"; do
  tgt="$FINAL_DIR/$p"
  [[ -e "$tgt" ]] || continue
  # -F: literal match; -n: line numbers; -r: recursive (dirs); -I: skip binary.
  while IFS= read -r line; do
    HIT_COUNT=$((HIT_COUNT+1))
    printf '    %s\n' "$line"
  done < <(grep -F -n -r -I --exclude-dir=.git --exclude="*.json" "$OLD_NAME" "$tgt" 2>/dev/null || true)
done
if [[ "$HIT_COUNT" -eq 0 ]]; then
  echo "    (none found)"
else
  echo
  printf '    %s%s hit(s) across prose.%s Review and rewrite — substitution is rarely the right rewording.\n' "$Y" "$HIT_COUNT" "$N"
fi

echo
printf '%s==>%s Done. Run check-drift.sh to verify sync:\n' "$B" "$N"
if [[ -n "$EXT_MARKETPLACE" ]]; then
  printf '    ./check-drift.sh %s --plugin %s\n' "$(dirname "$(dirname "$EXT_MARKETPLACE")")" "$NEW_NAME"
fi
if [[ -f "$FINAL_DIR/.claude-plugin/marketplace.json" ]]; then
  printf '    ./check-drift.sh %s\n' "$FINAL_DIR"
fi
