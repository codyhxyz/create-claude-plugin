#!/usr/bin/env bash
# check-submission.sh — pre-flight a Claude Code plugin for the official store
#
# Usage:  ./check-submission.sh <plugin-dir> [--offline]
#
# Reads <plugin-dir>/.claude-plugin/plugin.json + README, verifies every
# field the submission form requires is present + well-formed, and prints
# them ready to paste into https://claude.ai/settings/plugins/submit.

set -euo pipefail

PLUGIN_DIR="${1:-}"
OFFLINE="${2:-}"

if [[ -z "$PLUGIN_DIR" ]]; then
  echo "Usage: $0 <plugin-dir> [--offline]" >&2
  exit 2
fi
if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo "ERROR: '$PLUGIN_DIR' is not a directory" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required (brew install jq / apt install jq)" >&2
  exit 2
fi

MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
README="$PLUGIN_DIR/README.md"
LICENSE_FILE="$PLUGIN_DIR/LICENSE"

ERRORS=0
WARNINGS=0
err()  { echo "  ✗ $*" >&2; ERRORS=$((ERRORS+1)); }
warn() { echo "  ! $*" >&2; WARNINGS=$((WARNINGS+1)); }
ok()   { echo "  ✓ $*"; }

echo "==> Checking $PLUGIN_DIR"

# ---------- File presence ----------
echo "Files:"
[[ -f "$MANIFEST" ]] && ok ".claude-plugin/plugin.json" || { err "missing .claude-plugin/plugin.json"; exit 1; }
[[ -f "$README"   ]] && ok "README.md"                  || err "missing README.md"
[[ -f "$LICENSE_FILE" ]] && ok "LICENSE"                || warn "missing LICENSE file"

# ---------- Manifest fields ----------
echo "Manifest:"
NAME=$(jq -r '.name // empty' "$MANIFEST")
DESCRIPTION=$(jq -r '.description // empty' "$MANIFEST")
VERSION=$(jq -r '.version // empty' "$MANIFEST")
HOMEPAGE=$(jq -r '.homepage // empty' "$MANIFEST")
REPOSITORY=$(jq -r '.repository // empty' "$MANIFEST")
LICENSE_ID=$(jq -r '.license // empty' "$MANIFEST")
AUTHOR_NAME=$(jq -r '.author.name // empty' "$MANIFEST")
AUTHOR_EMAIL=$(jq -r '.author.email // empty' "$MANIFEST")

[[ -n "$NAME" ]]        && ok "name: $NAME"               || err "missing 'name'"
[[ -n "$DESCRIPTION" ]] && ok "description set"           || err "missing 'description'"
[[ -n "$VERSION" ]]     && ok "version: $VERSION"         || err "missing 'version'"
[[ -n "$REPOSITORY" ]]  && ok "repository: $REPOSITORY"   || err "missing 'repository' (= Plugin link)"
[[ -n "$AUTHOR_EMAIL" ]] && ok "author.email: $AUTHOR_EMAIL" || warn "missing 'author.email' (= Submitter email)"
[[ -n "$LICENSE_ID" ]]  && ok "license: $LICENSE_ID"      || warn "missing 'license' SPDX identifier"
[[ -n "$HOMEPAGE" ]]    && ok "homepage: $HOMEPAGE"       || warn "no 'homepage' (optional, often the README URL)"

# ---------- Naming rules ----------
echo "Naming:"
if [[ -n "$NAME" ]]; then
  if [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    ok "kebab-case"
  else
    err "'$NAME' is not kebab-case (lowercase + digits + hyphens only)"
  fi

  RESERVED=(claude-code-marketplace claude-code-plugins claude-plugins-official anthropic-marketplace anthropic-plugins agent-skills knowledge-work-plugins life-sciences)
  for r in "${RESERVED[@]}"; do
    if [[ "$NAME" == "$r" ]]; then err "'$NAME' is a reserved Anthropic name"; fi
  done

  if [[ "$NAME" == *"anthropic"* || "$NAME" == "official-"* || "$NAME" == "claude-"*"-official"* ]]; then
    warn "'$NAME' may impersonate an official Anthropic name"
  fi
fi

# ---------- Name availability check (online) ----------
if [[ "$OFFLINE" != "--offline" ]] && command -v curl >/dev/null 2>&1; then
  echo "Name availability (claude-plugins-official):"
  REMOTE_NAMES=$(curl -fsSL "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json" 2>/dev/null \
    | jq -r '.plugins[].name' 2>/dev/null || true)
  if [[ -z "$REMOTE_NAMES" ]]; then
    warn "could not fetch official marketplace (network or repo path changed) — skipping availability check"
  elif echo "$REMOTE_NAMES" | grep -qx "$NAME"; then
    err "name '$NAME' is already in claude-plugins-official"
  else
    ok "name '$NAME' is available in claude-plugins-official"
  fi
fi

# ---------- README examples ----------
echo "README:"
EXAMPLES_BLOCK=""
if [[ -f "$README" ]]; then
  # Pull everything between the first matching "## Example..." heading and the next heading
  EXAMPLES_BLOCK=$(awk 'BEGIN{IGNORECASE=1}
    /^## +Example/ { in_block=1; next }
    in_block && /^## / { exit }
    in_block { print }
  ' "$README" | sed -e '/^[[:space:]]*$/d')

  if [[ -n "$EXAMPLES_BLOCK" ]]; then
    EXAMPLE_LINES=$(echo "$EXAMPLES_BLOCK" | grep -c -i "example" || true)
    if [[ "$EXAMPLE_LINES" -ge 2 ]]; then
      ok "README has an Examples section with $EXAMPLE_LINES example lines"
    else
      warn "README has an Examples section but only $EXAMPLE_LINES example mentions — submission requires at least 2"
    fi
  else
    err "README is missing a '## Examples' or '## Example use cases' section"
  fi
fi

# ---------- Validation ----------
if command -v claude >/dev/null 2>&1; then
  echo "claude plugin validate:"
  if (cd "$PLUGIN_DIR" && claude plugin validate . >/dev/null 2>&1); then
    ok "passes"
  else
    err "fails — run 'cd $PLUGIN_DIR && claude plugin validate .' to see why"
  fi
else
  warn "'claude' CLI not found in PATH; skipping 'claude plugin validate'"
fi

# ---------- Summary ----------
echo
echo "==> Summary: $ERRORS error(s), $WARNINGS warning(s)"
if [[ "$ERRORS" -gt 0 ]]; then
  echo "Fix the errors above before submitting." >&2
  exit 1
fi

# ---------- Form-ready output ----------
cat <<EOF

================================================================
PASTE-READY SUBMISSION FIELDS
(https://claude.ai/settings/plugins/submit)
================================================================

[Page 2 — Plugin links]
Plugin link:          $REPOSITORY
Plugin homepage:      ${HOMEPAGE:-<leave blank>}

[Page 2 — Plugin details]
Plugin name:          $NAME
Plugin description:   $DESCRIPTION

Example use cases:
$(echo "$EXAMPLES_BLOCK" | sed 's/^/  /')

[Page 3 — Submission details]
Platforms:            <select the surfaces you've tested on>
License type:         ${LICENSE_ID:-<your license>}
Privacy policy URL:   <fill in IF your plugin transmits user data; else N/A>
Submitter email:      ${AUTHOR_EMAIL:-<your contact email>}

================================================================
EOF

if [[ "$WARNINGS" -gt 0 ]]; then
  echo "Note: $WARNINGS warning(s) above. Review before submitting." >&2
fi
