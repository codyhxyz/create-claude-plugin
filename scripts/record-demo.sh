#!/usr/bin/env bash
# record-demo.sh — render a plugin's hero asset.
#
# Primary path: `vhs docs/demo.tape` → docs/hero.gif.
# Fallback:     if VHS isn't installed, delegate to scripts/generate-wordmark.sh
#               to produce a static docs/hero.svg so the README still has a
#               hero that loads.
#
# VHS first-spawn flakiness: the ttyd that vhs launches sometimes fails its
# first navigation with `ERR_CONNECTION_REFUSED` (seen during Phase A4 of the
# dogfood). Retry once before giving up.
#
# Usage:  ./record-demo.sh [plugin-dir]
#   plugin-dir defaults to the current directory.

set -euo pipefail

PLUGIN_DIR="${1:-.}"
PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
TAPE="$PLUGIN_DIR/docs/demo.tape"
OUTPUT="$PLUGIN_DIR/docs/hero.gif"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORDMARK_SCRIPT="$SCRIPT_DIR/generate-wordmark.sh"

if ! command -v vhs >/dev/null 2>&1; then
  echo "!! vhs not installed (install with: brew install vhs)"
  if [[ -x "$WORDMARK_SCRIPT" ]]; then
    echo "==> Falling back to SVG wordmark"
    exec "$WORDMARK_SCRIPT" "$PLUGIN_DIR"
  else
    echo "ERROR: no SVG wordmark fallback found at $WORDMARK_SCRIPT" >&2
    exit 1
  fi
fi

if [[ ! -f "$TAPE" ]]; then
  echo "ERROR: no tape file at $TAPE" >&2
  echo "       Copy templates/plugin/docs/demo.tape from create-claude-plugin," >&2
  echo "       then customize the middle block for your demo." >&2
  exit 1
fi

render() {
  (cd "$PLUGIN_DIR" && vhs docs/demo.tape) 2>&1
}

echo "==> Rendering $TAPE"
OUT=$(render || true)
echo "$OUT"

# VHS exits 0 even on ttyd navigation errors — grep the stderr string instead
# of relying on $?. If the common first-spawn race bit us, retry once.
if echo "$OUT" | grep -q "ERR_CONNECTION_REFUSED\|navigation failed\|recording failed"; then
  echo "!! VHS hit a known first-spawn race — retrying once"
  sleep 1
  OUT=$(render || true)
  echo "$OUT"
fi

if [[ ! -f "$OUTPUT" ]]; then
  echo "ERROR: VHS did not produce $OUTPUT" >&2
  exit 1
fi

SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "==> Wrote $OUTPUT ($SIZE bytes)"
