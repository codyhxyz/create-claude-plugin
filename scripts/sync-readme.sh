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
#       the single-chord install one-liner (meta-marketplace chord)
#
#   <!-- auto:start-proof-of-value --> ... <!-- auto:end-proof-of-value -->
#       the proof-of-value artifact image + caption, pulled from
#       <plugin-dir>/marketing/proof-of-value.config.mjs when present
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
\`\`\`
/plugin marketplace add codyhxyz/codyhxyz-plugins && /plugin install ${NAME}@codyhxyz-plugins
\`\`\`
<!-- auto:end-install -->
EOF
)

# Proof-of-value block — populated from marketing/proof-of-value.config.mjs if present,
# otherwise a visible placeholder pointing at the proof-of-value skill.
POV_CONFIG="$PLUGIN_DIR/marketing/proof-of-value.config.mjs"
POV_PNG_REL="assets/proof-of-value.png"
POV_PNG="$PLUGIN_DIR/$POV_PNG_REL"
if [[ -f "$POV_CONFIG" && -f "$POV_PNG" ]]; then
  # Best-effort caption extraction via node one-liner. Don't import the whole
  # config module from bash — just read the `caption` field.
  POV_CAPTION=""
  if command -v node >/dev/null 2>&1; then
    POV_CAPTION=$(node --input-type=module -e "
      import('file://$POV_CONFIG').then((m) => {
        process.stdout.write(String(m.default?.caption ?? ''));
      }).catch(() => process.exit(0));
    " 2>/dev/null || echo "")
  fi
  POV_CAPTION_HTML=""
  if [[ -n "$POV_CAPTION" ]]; then
    # Escape HTML-hostile chars in the caption.
    POV_CAPTION_ESC=$(printf '%s' "$POV_CAPTION" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    POV_CAPTION_HTML=$'\n'"<p align=\"center\"><em>${POV_CAPTION_ESC}</em></p>"
  fi
  PROOF_OF_VALUE_BLOCK=$(cat <<EOF
<!-- auto:start-proof-of-value — rewritten by scripts/sync-readme.sh from marketing/proof-of-value.config.mjs -->
<p align="center">
  <img src="${POV_PNG_REL}" alt="${NAME} — proof of value" width="900">
</p>${POV_CAPTION_HTML}
<!-- auto:end-proof-of-value -->
EOF
)
else
  PROOF_OF_VALUE_BLOCK=$(cat <<'EOF'
<!-- auto:start-proof-of-value — rewritten by scripts/sync-readme.sh from marketing/proof-of-value.config.mjs -->
<p align="center"><em>(Run the <code>proof-of-value</code> skill to generate an artifact that answers <b>what does this plugin give me that I cannot already do?</b>)</em></p>
<!-- auto:end-proof-of-value -->
EOF
)
fi

# Splice a replacement block between two marker lines. Input: stdin = file
# content, args = start-marker-substring end-marker-substring replacement-block.
# Pure-bash implementation — BSD awk on macOS mis-tokenizes multi-line -v
# values ("newline in string"), so awk is off the table here.
splice() {
  local start_tag="$1" end_tag="$2" replacement="$3"
  local in_block=0 printed=0 line
  while IFS= read -r line; do
    if [[ $in_block -eq 1 ]]; then
      if [[ "$line" == *"$end_tag"* ]]; then
        if [[ $printed -eq 0 ]]; then
          printf '%s\n' "$replacement"
          printed=1
        fi
        in_block=0
      fi
      continue
    fi
    if [[ "$line" == *"$start_tag"* ]]; then
      in_block=1
      if [[ $printed -eq 0 ]]; then
        printf '%s\n' "$replacement"
        printed=1
      fi
      continue
    fi
    printf '%s\n' "$line"
  done
}

TMP=$(mktemp)
cat "$README" \
  | splice "<!-- auto:start —" "<!-- auto:end -->"                               "$HEADER_BLOCK" \
  | splice "<!-- auto:start-install"         "<!-- auto:end-install -->"         "$INSTALL_BLOCK" \
  | splice "<!-- auto:start-proof-of-value"  "<!-- auto:end-proof-of-value -->"  "$PROOF_OF_VALUE_BLOCK" \
  > "$TMP"

if diff -q "$README" "$TMP" >/dev/null 2>&1; then
  echo "==> README already in sync with plugin.json — no changes"
  rm -f "$TMP"
else
  mv "$TMP" "$README"
  echo "==> Rewrote auto-managed blocks in $README"
fi
