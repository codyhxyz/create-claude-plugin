#!/usr/bin/env bash
# publish-to-github.sh — idempotent GitHub repo create + edit for a Claude plugin
#
# Usage:  ./publish-to-github.sh <plugin-dir> [--owner <gh-owner>] [--private]
#
# Reads <plugin-dir>/.claude-plugin/plugin.json for name, description, and
# homepage. Auto-detects topics:
#   - baseline: claude-code, claude-code-plugin, claude-plugin
#   - component-type: claude-skill (skills/), claude-agent (agents/),
#                     claude-hook (hooks/), mcp (.mcp.json)
#   - manifest keywords[]
#
# Idempotent: if the repo already exists on GitHub for the current auth'd user
# (or the provided --owner), this skips `gh repo create` and proceeds straight
# to `gh repo edit`. In all cases, `gh repo edit` is run to sync description,
# homepage, and topics.
#
# Prereqs: gh (authenticated), jq.

set -euo pipefail

PLUGIN_DIR=""
OWNER=""
VISIBILITY="--public"

usage() {
  echo "Usage: $0 <plugin-dir> [--owner <gh-owner>] [--private]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)   OWNER="${2:-}"; shift 2 ;;
    --private) VISIBILITY="--private"; shift ;;
    --public)  VISIBILITY="--public"; shift ;;
    --help|-h) usage ;;
    *)         [[ -z "$PLUGIN_DIR" ]] && PLUGIN_DIR="$1"; shift ;;
  esac
done

[[ -z "$PLUGIN_DIR" ]] && usage
[[ ! -d "$PLUGIN_DIR" ]] && { echo "ERROR: '$PLUGIN_DIR' is not a directory" >&2; exit 2; }

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 2; }

MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }

NAME=$(jq -r '.name // empty' "$MANIFEST")
DESCRIPTION=$(jq -r '.description // empty' "$MANIFEST")
HOMEPAGE=$(jq -r '.homepage // empty' "$MANIFEST")

[[ -z "$NAME" ]]        && { echo "ERROR: plugin.json missing 'name'" >&2; exit 1; }
[[ -z "$DESCRIPTION" ]] && { echo "ERROR: plugin.json missing 'description'" >&2; exit 1; }

# Resolve owner: --owner flag wins, else the authed gh user
if [[ -z "$OWNER" ]]; then
  OWNER=$(gh api user --jq .login 2>/dev/null || true)
  [[ -z "$OWNER" ]] && { echo "ERROR: gh not authenticated (run 'gh auth login')" >&2; exit 1; }
fi
SLUG="$OWNER/$NAME"

# ---------- Auto-detect topics ----------
TOPICS=(claude-code claude-code-plugin claude-plugin)
[[ -d "$PLUGIN_DIR/skills" ]] && TOPICS+=(claude-skill)
[[ -d "$PLUGIN_DIR/agents" ]] && TOPICS+=(claude-agent)
[[ -d "$PLUGIN_DIR/hooks"  ]] && TOPICS+=(claude-hook)
[[ -f "$PLUGIN_DIR/.mcp.json" ]] && TOPICS+=(mcp)

# Add manifest keywords (filter to gh topic rules: lowercase alnum + hyphens, <=50 chars)
while IFS= read -r kw; do
  [[ -z "$kw" ]] && continue
  kw_norm=$(echo "$kw" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/^-*//;s/-*$//' | cut -c1-50)
  [[ -z "$kw_norm" ]] && continue
  TOPICS+=("$kw_norm")
done < <(jq -r '.keywords[]? // empty' "$MANIFEST")

# Dedupe topics
UNIQ_TOPICS=()
for t in "${TOPICS[@]}"; do
  skip=""
  for u in "${UNIQ_TOPICS[@]:-}"; do [[ "$u" == "$t" ]] && skip=1 && break; done
  [[ -z "$skip" ]] && UNIQ_TOPICS+=("$t")
done

# ---------- Ensure a git repo + initial commit ----------
if [[ ! -d "$PLUGIN_DIR/.git" ]]; then
  echo "==> Initializing git repo in $PLUGIN_DIR"
  (cd "$PLUGIN_DIR" && git init -q && git add -A && git commit -q -m "Initial commit" || true)
fi

# ---------- Create repo (idempotent) ----------
if gh repo view "$SLUG" >/dev/null 2>&1; then
  echo "==> Repo $SLUG already exists on GitHub — skipping create"
else
  echo "==> Creating $SLUG on GitHub"
  (cd "$PLUGIN_DIR" && gh repo create "$SLUG" $VISIBILITY \
    --source=. --remote=origin --push \
    --description "$DESCRIPTION")
fi

# ---------- Always edit (idempotent sync of description/homepage/topics) ----------
echo "==> Syncing repo metadata on $SLUG"
EDIT_ARGS=(--description "$DESCRIPTION")
[[ -n "$HOMEPAGE" ]] && EDIT_ARGS+=(--homepage "$HOMEPAGE")
for t in "${UNIQ_TOPICS[@]}"; do EDIT_ARGS+=(--add-topic "$t"); done
gh repo edit "$SLUG" "${EDIT_ARGS[@]}"

echo "==> Done: https://github.com/$SLUG"
echo "    Topics: ${UNIQ_TOPICS[*]}"
