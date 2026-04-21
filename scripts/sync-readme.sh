#!/usr/bin/env bash
# sync-readme.sh — rewrite the auto-managed blocks in a plugin README.
#
# Reads <plugin-dir>/.claude-plugin/plugin.json and rewrites the content
# between these marker pairs in <plugin-dir>/README.md:
#
#   <!-- auto:start --> ... <!-- auto:end -->
#       header + badges + hero image
#
#   <!-- auto:start-install --> ... <!-- auto:end-install -->
#       the Quick Start install block (meta-marketplace + direct + local)
#
# Anything outside the markers is left alone. Idempotent — same input,
# same output, zero diff on re-run.
#
# Usage:  ./sync-readme.sh [plugin-dir]
#   plugin-dir defaults to current directory.
#
# Prereqs: jq.

set -euo pipefail

PLUGIN_DIR="${1:-.}"
PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
README="$PLUGIN_DIR/README.md"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 2; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }
[[ -f "$README"   ]] || { echo "ERROR: missing $README (run the scaffold first)" >&2; exit 1; }

NAME=$(jq -r '.name // empty'        "$MANIFEST")
DESCRIPTION=$(jq -r '.description // empty' "$MANIFEST")
REPOSITORY=$(jq -r '.repository // empty'   "$MANIFEST")

[[ -n "$NAME" ]]        || { echo "ERROR: plugin.json missing 'name'"        >&2; exit 1; }
[[ -n "$DESCRIPTION" ]] || { echo "ERROR: plugin.json missing 'description'" >&2; exit 1; }

# Parse owner/repo from .repository. Accept the usual URL shapes.
OWNER_REPO=$(echo "$REPOSITORY" \
  | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##; s#^/+##; s#/+$##')
case "$OWNER_REPO" in
  */*) OWNER="${OWNER_REPO%%/*}"; REPO="${OWNER_REPO##*/}" ;;
  *)   OWNER="YOUR_GH_USER"; REPO="$NAME" ;;  # fall back to template placeholders
esac

# URL-encode the manifest path for the shields.io filename param.
MANIFEST_QS="$(printf '.claude-plugin/plugin.json' | sed 's#/#%2F#g')"

HEADER_BLOCK=$(cat <<EOF
<!-- auto:start — rewritten by scripts/sync-readme.sh from plugin.json; do not hand-edit between these markers -->
<h1 align="center">${NAME}</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href=".claude-plugin/plugin.json"><img src="https://img.shields.io/github/package-json/v/${OWNER}/${REPO}?filename=${MANIFEST_QS}&label=version" alt="Version"></a>
  <a href="https://claude.com/product/claude-code"><img src="https://img.shields.io/badge/built_for-Claude%20Code-d97706" alt="Built for Claude Code"></a>
</p>

<p align="center"><b>${DESCRIPTION}</b></p>

<p align="center">
  <img src="docs/hero.gif" alt="${NAME} demo" width="900">
</p>
<!-- auto:end -->
EOF
)

INSTALL_BLOCK=$(cat <<EOF
<!-- auto:start-install — rewritten by scripts/sync-readme.sh -->
### Option 1 — install from the codyhxyz-plugins marketplace *(recommended)*

\`\`\`
/plugin marketplace add codyhxyz/codyhxyz-plugins && /plugin install ${NAME}@codyhxyz-plugins
\`\`\`

### Option 2 — install directly from this repo

\`\`\`
/plugin marketplace add ${OWNER}/${REPO} && /plugin install ${NAME}@${NAME}
\`\`\`

### Option 3 — local smoke test

\`\`\`bash
git clone https://github.com/${OWNER}/${REPO}
claude --plugin-dir ./${REPO}
\`\`\`
<!-- auto:end-install -->
EOF
)

# Splice a replacement block between two marker lines. Input: stdin = file
# content, args = start-marker-substring end-marker-substring replacement-block.
splice() {
  local start_tag="$1" end_tag="$2" replacement="$3"
  awk -v S="$start_tag" -v E="$end_tag" -v R="$replacement" '
    BEGIN { in_block = 0; printed_replacement = 0 }
    {
      if (in_block) {
        if (index($0, E) > 0) {
          if (!printed_replacement) { print R; printed_replacement = 1 }
          in_block = 0
          next
        }
        next
      }
      if (index($0, S) > 0) {
        in_block = 1
        if (!printed_replacement) { print R; printed_replacement = 1 }
        next
      }
      print $0
    }
  '
}

TMP=$(mktemp)
cat "$README" \
  | splice "<!-- auto:start —" "<!-- auto:end -->"                "$HEADER_BLOCK" \
  | splice "<!-- auto:start-install"  "<!-- auto:end-install -->" "$INSTALL_BLOCK" \
  > "$TMP"

if diff -q "$README" "$TMP" >/dev/null 2>&1; then
  echo "==> README already in sync with plugin.json — no changes"
  rm -f "$TMP"
else
  mv "$TMP" "$README"
  echo "==> Rewrote auto-managed blocks in $README"
fi
