#!/usr/bin/env bash
# session-start-banner.sh — one-line status banner for SessionStart hook
#
# Fires on every Claude Code session. Prints a one-liner IF the session's cwd
# contains a .claude-plugin/plugin.json (= the user is inside a plugin repo).
# Otherwise exits silently and fast — this runs in the critical path of every
# session, so it must stay cheap.
#
# The banner points the user at the create-claude-plugin skill for guidance.
# Use --quiet on the underlying script to keep output to one line and avoid
# blocking session start on slow checks (validate is skipped via --offline).

set -euo pipefail

# Exit fast if cwd isn't a plugin. No stderr, no delay.
if [[ ! -f "$PWD/.claude-plugin/plugin.json" ]]; then
  exit 0
fi

# ${CLAUDE_PLUGIN_ROOT} is set by Claude Code when hooks run from an installed
# plugin. Fall back to the script's own directory when running in development
# via --plugin-dir.
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CHECK="$ROOT/scripts/check-submission.sh"

if [[ ! -x "$CHECK" ]]; then
  # Silently bail — don't spam the session on a broken install.
  exit 0
fi

# --offline avoids network calls on every session start (GitHub reachability,
# marketplace name availability). --status --quiet collapses to one line.
# Use `timeout` (or GNU coreutils' `gtimeout` on macOS) when available so a
# hung validate can't stall session startup. Fall back to direct invocation on
# systems without either; the status script is fast in practice (<1s locally).
if command -v timeout >/dev/null 2>&1; then
  OUTPUT=$(timeout 5s "$CHECK" "$PWD" --offline --status --quiet 2>/dev/null || true)
elif command -v gtimeout >/dev/null 2>&1; then
  OUTPUT=$(gtimeout 5s "$CHECK" "$PWD" --offline --status --quiet 2>/dev/null || true)
else
  OUTPUT=$("$CHECK" "$PWD" --offline --status --quiet 2>/dev/null || true)
fi

# Only emit if we got a banner back. An empty result means something went wrong
# upstream — stay silent rather than print garbage.
if [[ -n "$OUTPUT" ]]; then
  echo "$OUTPUT"
fi
