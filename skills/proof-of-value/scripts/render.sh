#!/usr/bin/env bash
# render.sh — thin wrapper around render.mjs. Handles the one-time
# `npm install @resvg/resvg-js` in the skill directory, then runs the
# renderer. Subsequent invocations skip the install step.
#
# usage: render.sh <path/to/proof-of-value.config.mjs>

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <path/to/proof-of-value.config.mjs>" >&2
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  echo "proof-of-value: node is required (install Node ≥18 from nodejs.org)" >&2
  exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "proof-of-value: npm is required (ships with Node)" >&2
  exit 1
fi

# One-time install. Runs in the skill dir, not the user's plugin dir, so the
# user's plugin stays dep-free.
if [[ ! -d "$SKILL_DIR/node_modules/@resvg" ]]; then
  echo "proof-of-value: first-run setup — installing renderer deps (one time)..." >&2
  (cd "$SKILL_DIR" && npm install --silent --no-audit --no-fund)
fi

exec node "$SKILL_DIR/scripts/render.mjs" "$@"
