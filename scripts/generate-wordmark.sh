#!/usr/bin/env bash
# generate-wordmark.sh — produce a static SVG hero when VHS isn't available.
#
# Reads <plugin-dir>/.claude-plugin/plugin.json for the plugin name and
# description, then writes <plugin-dir>/docs/hero.svg. A README that points
# at docs/hero.gif will 404, so callers should either:
#   - swap the hero <img> to docs/hero.svg, or
#   - run scripts/record-demo.sh on a machine with VHS installed.
#
# Usage:  ./generate-wordmark.sh [plugin-dir]

set -euo pipefail

PLUGIN_DIR="${1:-.}"
PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 2; }
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }

NAME=$(jq -r '.name // "plugin"' "$MANIFEST")
DESCRIPTION=$(jq -r '.description // ""' "$MANIFEST")

mkdir -p "$PLUGIN_DIR/docs"
OUTPUT="$PLUGIN_DIR/docs/hero.svg"

# XML-escape manifest strings — safe against & < > " ' in names/descriptions.
xml_escape() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
}

NAME_ESC=$(xml_escape "$NAME")
DESC_ESC=$(xml_escape "$DESCRIPTION")

cat > "$OUTPUT" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 360" role="img" aria-label="${NAME_ESC}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"  stop-color="#1e1b2e"/>
      <stop offset="100%" stop-color="#0c0a18"/>
    </linearGradient>
  </defs>
  <rect width="900" height="360" fill="url(#bg)" rx="16"/>
  <text x="450" y="165" text-anchor="middle"
        font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
        font-size="58" font-weight="700" fill="#f8f5ff" letter-spacing="-1.5">
    ${NAME_ESC}
  </text>
  <text x="450" y="225" text-anchor="middle"
        font-family="ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif"
        font-size="20" fill="#c8bfe6">
    ${DESC_ESC}
  </text>
  <text x="450" y="305" text-anchor="middle"
        font-family="ui-sans-serif, -apple-system, BlinkMacSystemFont, sans-serif"
        font-size="14" fill="#8678b8" letter-spacing="2">
    BUILT FOR CLAUDE CODE
  </text>
</svg>
EOF

echo "==> Wrote $OUTPUT"
echo "    Update your README to reference docs/hero.svg (or install VHS and run record-demo.sh)."
