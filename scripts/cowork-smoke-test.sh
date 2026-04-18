#!/usr/bin/env bash
# cowork-smoke-test.sh — end-to-end automated Cowork install + smoke-test.
#
# Drives the Cowork desktop app via @github/computer-use-mcp in a headless
# `claude -p` subprocess. One consent (add the MCP if missing + grant macOS
# permissions the first time), then everything runs autonomously.
#
# Usage:  ./cowork-smoke-test.sh <plugin-dir> [--yes] [--test-prompt "..."]
#
# Flags:
#   --yes                  Skip the pre-run confirmation (for CI / re-runs).
#   --test-prompt "..."    Override the auto-detected README test prompt.
#
# On PASS: runs `check-submission.sh <plugin-dir> --no-open` with
#          COWORK_TESTED=yes so the Cowork checkbox unlocks.
# On FAIL: prints the subprocess output and exits 1. Cowork gate stays closed.
#
# Prereqs: macOS, Claude Pro/Max, Claude Code ≥ v2.1.85, Claude desktop app.
# The first run also needs you to grant the desktop app Accessibility + Screen
# Recording via System Settings — macOS won't let any script bypass that.

set -euo pipefail

SKIP_CONFIRM=""
OVERRIDE_PROMPT=""
PLUGIN_DIR=""
for arg in "$@"; do
  case "$arg" in
    --yes|-y)           SKIP_CONFIRM="1" ;;
    --test-prompt)      shift; OVERRIDE_PROMPT="${1:-}" ;;
    --help|-h)          echo "Usage: $0 <plugin-dir> [--yes] [--test-prompt \"...\"]"; exit 0 ;;
    --*)                echo "Unknown flag: $arg" >&2; exit 2 ;;
    *)                  [[ -z "$PLUGIN_DIR" ]] && PLUGIN_DIR="$arg" ;;
  esac
done

[[ -z "$PLUGIN_DIR" ]] && { echo "Usage: $0 <plugin-dir> [--yes] [--test-prompt \"...\"]" >&2; exit 2; }
PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_TMPL="$SKILL_ROOT/skills/create-claude-plugin/templates/cowork-autonomous-prompt.md"
CHECK_SCRIPT="$SKILL_ROOT/scripts/check-submission.sh"

# ---------- Prereqs ----------
[[ "$OSTYPE" == "darwin"* ]] || { echo "ERROR: macOS required for Cowork testing" >&2; exit 1; }
command -v claude >/dev/null || { echo "ERROR: claude CLI required (install Claude Code)" >&2; exit 1; }
command -v jq >/dev/null     || { echo "ERROR: jq required" >&2; exit 1; }
command -v npx >/dev/null    || { echo "ERROR: npx required (install Node ≥18)" >&2; exit 1; }
[[ -f "$PROMPT_TMPL" ]]      || { echo "ERROR: missing $PROMPT_TMPL" >&2; exit 1; }
[[ -d "/Applications/Claude.app" ]] || { echo "ERROR: Claude desktop app not found at /Applications/Claude.app" >&2; exit 1; }

# Plugin metadata
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }
NAME=$(jq -r '.name // empty' "$MANIFEST")
[[ -n "$NAME" ]]   || { echo "ERROR: $MANIFEST missing 'name'" >&2; exit 1; }

# Auto-detect test prompt from README Usage section (first quoted line), else fallback
if [[ -n "$OVERRIDE_PROMPT" ]]; then
  TEST_PROMPT="$OVERRIDE_PROMPT"
else
  TEST_PROMPT=$(awk '/^## +Usage/{flag=1; next} flag && /^## /{exit} flag' "$PLUGIN_DIR/README.md" 2>/dev/null \
    | awk '/^> +"/ {sub(/^> +"/,""); sub(/"[[:space:]]*$/,""); print; exit}')
  [[ -z "$TEST_PROMPT" ]] && TEST_PROMPT="Invoke the $NAME plugin's main skill with a realistic input."
fi

# ---------- Ensure computer-use MCP is configured (user scope) ----------
# The bare name "computer-use" is reserved by Claude Code (for a future
# first-party built-in, presumably), so we add @github/computer-use-mcp
# under the namespaced alias "gh-computer-use". Tool names follow suit:
# mcp__gh-computer-use__<tool>.
MCP_NAME="gh-computer-use"
needs_mcp_add="0"
if ! claude mcp list 2>&1 | grep -qi "^${MCP_NAME}:"; then
  needs_mcp_add="1"
fi

# ---------- Single confirmation gate ----------
if [[ "$SKIP_CONFIRM" != "1" ]]; then
  cat <<EOF
==> Cowork smoke-test plan for: $NAME
      plugin dir:  $PLUGIN_DIR
      test prompt: $TEST_PROMPT

Actions this script will take:
EOF
  if [[ "$needs_mcp_add" == "1" ]]; then
    echo "  1. Add @github/computer-use-mcp at USER scope (one-time, ~30s first install)"
    echo "     → gives headless Claude the ability to click/type/screenshot your Mac"
    echo "  2. Spawn a headless \`claude -p\` subprocess that drives Claude.app (~2-3 min)"
  else
    echo "  1. Spawn a headless \`claude -p\` subprocess that drives Claude.app (~2-3 min)"
    echo "     (computer-use MCP is already configured)"
  fi
  echo "  3. On PASS: flip COWORK_TESTED=yes via check-submission.sh"
  echo
  echo "NOTE: the first run also needs Claude.app to have Accessibility + Screen"
  echo "      Recording permissions (System Settings → Privacy & Security)."
  echo "      macOS requires you to click those switches — no script can."
  echo
  read -r -p "Proceed? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

# ---------- Add the MCP if missing ----------
if [[ "$needs_mcp_add" == "1" ]]; then
  echo "==> Adding $MCP_NAME MCP at user scope"
  claude mcp add "$MCP_NAME" --scope user -- npx -y @github/computer-use-mcp
  echo "    done"
fi

# ---------- Build the autonomous prompt ----------
PROMPT=$(sed \
  -e "s|{{PLUGIN_NAME}}|$NAME|g" \
  -e "s|{{PLUGIN_PATH}}|$PLUGIN_DIR|g" \
  -e "s|{{TEST_PROMPT}}|$TEST_PROMPT|g" \
  "$PROMPT_TMPL")

# ---------- Run the subprocess ----------
# Isolation strategy:
#   --bare                    skip CLAUDE.md auto-discovery, hooks, SessionStart, etc.
#                             Without this, the subprocess inherits the current project's
#                             context and goes conversational instead of executing.
#   --mcp-config <json>       explicitly load only the gh-computer-use MCP — don't
#                             drag in the user's full MCP set (Notion, Gmail, etc.).
#   --system-prompt           override the default "friendly assistant" posture with
#                             a headless-automation posture.
#   --permission-mode bypass  + --allowedTools narrow list = no per-call prompts for
#                             the tools the prompt actually needs; stray calls blocked.
#   --output-format text      keeps the COWORK_TEST_RESULT marker greppable at the tail.
#   --max-budget-usd 2        API-key billing safety rail if the subprocess loops.
#
# The `cd /tmp` keeps the subprocess out of this project dir so even without
# --bare, no project CLAUDE.md would be picked up.
echo "==> Running autonomous Cowork test (~2-3 min — stay out of the way so the Mac doesn't fight the automation)"
LOG=$(mktemp -t cowork-test.XXXXXX)
MCP_CFG=$(mktemp -t cowork-mcp.XXXXXX.json)
trap 'rm -f "$LOG" "$MCP_CFG"' EXIT

cat > "$MCP_CFG" <<'JSON'
{
  "mcpServers": {
    "gh-computer-use": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@github/computer-use-mcp"]
    }
  }
}
JSON

SYSTEM_PROMPT='You are a headless automation agent running inside claude -p with no human in the loop. Execute the task in the user message exactly. Do NOT ask questions. Do NOT offer alternatives. Do NOT summarize. Use the mcp__gh-computer-use__* tools to drive the macOS desktop. End every response with the COWORK_TEST_RESULT marker the prompt requires.'

# NB: we do NOT pass --bare because --bare disables keychain reads and the
# subscription-authenticated user won't have ANTHROPIC_API_KEY set. Instead
# we isolate via cwd=/tmp (no project CLAUDE.md), --setting-sources "" (no
# user/project/local settings), and --system-prompt (override the default
# posture). MCPs load exclusively from --mcp-config.
if (cd /tmp && claude -p "$PROMPT" \
     --setting-sources "" \
     --strict-mcp-config \
     --mcp-config "$MCP_CFG" \
     --system-prompt "$SYSTEM_PROMPT" \
     --permission-mode bypassPermissions \
     --allowedTools "mcp__gh-computer-use__* Bash Read Write" \
     --output-format text \
     --max-budget-usd 2 \
     --disable-slash-commands \
     > "$LOG" 2>&1); then
  SUBPROC_EXIT=0
else
  SUBPROC_EXIT=$?
fi

# ---------- Interpret ----------
LAST_MARKER=$(grep -E 'COWORK_TEST_RESULT: ' "$LOG" | tail -1 || true)

if [[ "$LAST_MARKER" == *"PASS"* ]]; then
  echo "==> PASS"
  echo "==> Flipping COWORK_TESTED=yes via check-submission.sh"
  COWORK_TESTED=yes "$CHECK_SCRIPT" "$PLUGIN_DIR" --no-open --offline | tail -5
  echo
  echo "Cowork gate unlocked. You can now claim 'Claude Cowork' on the submission form."
  exit 0
fi

echo "==> FAIL or inconclusive (subprocess exit: $SUBPROC_EXIT)"
if [[ -n "$LAST_MARKER" ]]; then
  echo "    marker: $LAST_MARKER"
else
  echo "    no COWORK_TEST_RESULT marker emitted — test likely timed out or errored early"
fi

# Detect the specific "macOS didn't grant permissions" failure mode and give
# the user a direct path to System Settings — don't just dump the log and
# make them hunt. This failure is EXTREMELY common on first run.
if [[ "$LAST_MARKER" == *"request_access"* ]] || grep -q "declined\|Screen Recording\|Accessibility" "$LOG"; then
  echo
  echo "==> This is the common first-run failure: Claude.app lacks macOS permissions"
  echo
  echo "    Grant BOTH of these to Claude (the desktop app) in System Settings:"
  echo "      • Screen Recording  (so the automation can screenshot)"
  echo "      • Accessibility     (so the automation can click + type)"
  echo
  echo "    I'll open the relevant Settings panes now. After flipping both switches ON,"
  echo "    quit + relaunch Claude.app, then re-run:"
  echo "      $0 $PLUGIN_DIR --yes"
  echo
  if command -v open >/dev/null 2>&1; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" 2>/dev/null || true
    sleep 1
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
    echo "    → Opened Screen Recording + Accessibility settings panes."
  fi
  exit 2
fi

echo
echo "Last 40 lines of subprocess output:"
tail -40 "$LOG" | sed 's/^/    /'
exit 1
