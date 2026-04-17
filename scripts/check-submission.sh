#!/usr/bin/env bash
# check-submission.sh — pre-flight a Claude Code plugin for the official store
#
# Usage:  ./check-submission.sh <plugin-dir> [--offline]
#
# Reads <plugin-dir>/.claude-plugin/plugin.json + README, verifies every
# field the submission form requires is present + well-formed, and prints
# them ready to paste into https://claude.ai/settings/plugins/submit.

set -euo pipefail

PLUGIN_DIR=""
OFFLINE=""
PRINT_COWORK_PROMPT=""
for arg in "$@"; do
  case "$arg" in
    --offline)              OFFLINE="--offline" ;;
    --print-cowork-prompt)  PRINT_COWORK_PROMPT="yes" ;;
    --help|-h)              echo "Usage: $0 <plugin-dir> [--offline] [--print-cowork-prompt]"; exit 0 ;;
    *)                      [[ -z "$PLUGIN_DIR" ]] && PLUGIN_DIR="$arg" ;;
  esac
done

if [[ -z "$PLUGIN_DIR" ]]; then
  echo "Usage: $0 <plugin-dir> [--offline] [--print-cowork-prompt]" >&2
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

# ---------- Validation (Claude Code) ----------
if command -v claude >/dev/null 2>&1; then
  echo "claude plugin validate (Claude Code):"
  if (cd "$PLUGIN_DIR" && claude plugin validate . >/dev/null 2>&1); then
    ok "passes"
  else
    err "fails — run 'cd $PLUGIN_DIR && claude plugin validate .' to see why"
  fi
else
  warn "'claude' CLI not found in PATH; skipping 'claude plugin validate'"
fi

# ---------- Cross-surface portability ----------
# Claude Code and Claude Cowork share the same plugin format and marketplace,
# but Cowork has no CLI/--plugin-dir — install + test is manual via the
# desktop app UI. We can't automate Cowork; we CAN flag features that are
# known Code-only (or unverified on Cowork) so the human knows what to test
# manually before claiming Cowork support on the submission form.
echo "Cross-surface portability:"
PORTABILITY_FLAGS=()
[[ -d "$PLUGIN_DIR/skills"  ]] && ok "skills/   — portable (Code + Cowork)"
[[ -d "$PLUGIN_DIR/agents"  ]] && ok "agents/   — portable (Code + Cowork)"
if [[ -d "$PLUGIN_DIR/hooks" || -f "$PLUGIN_DIR/hooks/hooks.json" ]]; then
  warn "hooks/    — Cowork support unverified; Code event model may not match. TEST IN COWORK before claiming support."
  PORTABILITY_FLAGS+=("hooks")
fi
if [[ -f "$PLUGIN_DIR/.mcp.json" ]]; then
  ok ".mcp.json — likely portable (Cowork integrates external apps via MCP), but TEST."
fi
if [[ -f "$PLUGIN_DIR/.lsp.json" ]]; then
  warn ".lsp.json — Claude Code only (LSP is Code's code-intelligence surface). Don't claim Cowork support."
  PORTABILITY_FLAGS+=("lsp")
fi
if [[ -d "$PLUGIN_DIR/monitors" || -f "$PLUGIN_DIR/monitors/monitors.json" ]]; then
  warn "monitors/ — Claude Code only (interactive CLI sessions). Don't claim Cowork support."
  PORTABILITY_FLAGS+=("monitors")
fi
if [[ -d "$PLUGIN_DIR/bin" ]]; then
  warn "bin/      — Claude Code only (modifies the Bash tool's PATH). Don't claim Cowork support."
  PORTABILITY_FLAGS+=("bin")
fi
if [[ -f "$PLUGIN_DIR/settings.json" ]]; then
  warn "settings.json — likely Code only (only 'agent' + 'subagentStatusLine' keys honored). Verify before claiming Cowork."
fi
if [[ ${#PORTABILITY_FLAGS[@]} -eq 0 ]]; then
  ok "no Code-only features detected — plugin should be portable to Cowork (still requires manual install + test)"
fi

# ---------- Cowork manual confirmation ----------
# Cowork has no CLI. Force the human to confirm they've actually tested it
# before claiming Cowork as a supported platform on the submission form.
echo "Cowork manual test:"
echo "  Path A (manual):     Claude desktop → Cowork tab → Customize → Browse plugins → Install / .zip upload"
echo "  Path B (macOS Pro+): in interactive Claude Code, /mcp → enable 'computer-use', then re-run this script with --print-cowork-prompt to get a paste-ready prompt that drives the test"
if [[ "${COWORK_TESTED:-}" == "yes" ]]; then
  ok "COWORK_TESTED=yes — you've confirmed manual install + smoke test passed"
else
  warn "Cowork install + smoke test NOT confirmed. Set COWORK_TESTED=yes after testing (manually or via Path B), or DO NOT select Cowork in Platforms."
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
Platforms:            Claude Code$( [[ "${COWORK_TESTED:-}" == "yes" ]] && echo ", Claude Cowork" )    # only what you've actually tested
License type:         ${LICENSE_ID:-<your license>}
Privacy policy URL:   <fill in IF your plugin transmits user data; else N/A>
Submitter email:      ${AUTHOR_EMAIL:-<your contact email>}

================================================================
EOF

if [[ "$WARNINGS" -gt 0 ]]; then
  echo "Note: $WARNINGS warning(s) above. Review before submitting." >&2
fi

# ---------- Optional: paste-ready Cowork test prompt for Claude Code Computer Use ----------
if [[ "$PRINT_COWORK_PROMPT" == "yes" ]]; then
  # Pick a test prompt: prefer the first ">" quoted line in README's Usage section, else fallback
  TEST_PROMPT=$(awk '/^## +Usage/{flag=1; next} flag && /^## /{exit} flag' "$README" 2>/dev/null \
    | awk '/^> +"/ {sub(/^> +"/,""); sub(/"[[:space:]]*$/,""); print; exit}' )
  [[ -z "$TEST_PROMPT" ]] && TEST_PROMPT="(invoke the plugin's main skill with a realistic input)"

  ABS_PLUGIN_DIR=$(cd "$PLUGIN_DIR" && pwd)
  cat <<EOF

================================================================
COWORK TEST PROMPT — paste into an INTERACTIVE Claude Code session
(prereqs: macOS, Pro/Max, Claude Code ≥ v2.1.85, /mcp → enable
'computer-use', then grant macOS Accessibility + Screen Recording)
================================================================

Open the Claude desktop app and switch to the Cowork tab. Click
Customize → Browse plugins. If "${NAME}" appears in the marketplace,
install it from there; otherwise zip the directory at
'${ABS_PLUGIN_DIR}' and upload the .zip via the same UI.

Once installed, start a Cowork session and run this test prompt:

  ${TEST_PROMPT}

Verify the plugin's main skill responds as described in its README.
Screenshot any errors. Report whether the smoke test passed.

If it passed, I will run: export COWORK_TESTED=yes
================================================================
EOF
fi
