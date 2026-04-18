#!/usr/bin/env bash
# check-submission.sh — pre-flight a Claude Code plugin for the official store,
# OR report phase-grouped status mid-development with --status.
#
# Usage:  ./check-submission.sh <plugin-dir> [--offline] [--no-open] [--print-cowork-prompt] [--status [--quiet]]
#
# Reads <plugin-dir>/.claude-plugin/plugin.json + README, verifies every
# field the submission form requires is present + well-formed, and prints
# them ready to paste into https://claude.ai/settings/plugins/submit.
#
# After a clean pre-flight (0 errors), on macOS this script also:
#   - copies the Examples block to the clipboard via pbcopy
#   - opens the submission form in the browser via `open`
# Pass --no-open (or set CCP_NO_OPEN=1) to skip the clipboard + browser step
# for CI / non-interactive use.
#
# --status mode: runs the same checks but tolerates incomplete state (exit 0),
# skips the clipboard/open handoff, and emits a phase-grouped report keyed to
# the 7 phases of the create-claude-plugin skill. Use mid-development to answer
# "what's left before I can submit?". Add --quiet to collapse the report to a
# one-line banner suitable for SessionStart hooks.

set -euo pipefail

SUBMIT_URL="https://claude.ai/settings/plugins/submit"

PLUGIN_DIR=""
OFFLINE=""
PRINT_COWORK_PROMPT=""
NO_OPEN="${CCP_NO_OPEN:-}"
STATUS_MODE=""
QUIET_MODE=""
for arg in "$@"; do
  case "$arg" in
    --offline)              OFFLINE="--offline" ;;
    --print-cowork-prompt)  PRINT_COWORK_PROMPT="yes" ;;
    --no-open)              NO_OPEN="1" ;;
    --status)               STATUS_MODE="1"; NO_OPEN="1" ;;
    --quiet)                QUIET_MODE="1" ;;
    --help|-h)              echo "Usage: $0 <plugin-dir> [--offline] [--no-open] [--print-cowork-prompt] [--status [--quiet]]"; exit 0 ;;
    *)                      [[ -z "$PLUGIN_DIR" ]] && PLUGIN_DIR="$arg" ;;
  esac
done

if [[ -z "$PLUGIN_DIR" ]]; then
  echo "Usage: $0 <plugin-dir> [--offline] [--no-open] [--print-cowork-prompt] [--status [--quiet]]" >&2
  exit 2
fi
if [[ -n "$QUIET_MODE" && -z "$STATUS_MODE" ]]; then
  echo "ERROR: --quiet only makes sense with --status" >&2
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
VALIDATE_OK=""
# In --quiet mode (SessionStart banner use case), silence the verbose
# per-check trace on both stdout and stderr — only the final one-line
# banner goes to stdout.
if [[ -n "$QUIET_MODE" ]]; then
  err()  { ERRORS=$((ERRORS+1)); }
  warn() { WARNINGS=$((WARNINGS+1)); }
  ok()   { :; }
  echo() { :; }
else
  err()  { command echo "  ✗ $*" >&2; ERRORS=$((ERRORS+1)); }
  warn() { command echo "  ! $*" >&2; WARNINGS=$((WARNINGS+1)); }
  ok()   { command echo "  ✓ $*"; }
fi

echo "==> Checking $PLUGIN_DIR"

# ---------- File presence ----------
echo "Files:"
if [[ -f "$MANIFEST" ]]; then
  ok ".claude-plugin/plugin.json"
else
  err "missing .claude-plugin/plugin.json"
  # In status mode, keep going so we can emit the phase report; classic mode stops.
  [[ -z "$STATUS_MODE" ]] && exit 1
fi
[[ -f "$README"   ]] && ok "README.md"                  || err "missing README.md"
[[ -f "$LICENSE_FILE" ]] && ok "LICENSE"                || warn "missing LICENSE file"
# CLAUDE.md grounds every future session in the project's rules. Warn on
# missing (not err) so pre-CLAUDE.md plugins don't regress on classic mode.
CLAUDE_MD="$PLUGIN_DIR/CLAUDE.md"
[[ -f "$CLAUDE_MD" ]] && ok "CLAUDE.md" || warn "missing CLAUDE.md — copy templates/plugin/CLAUDE.md in so future sessions know this is a plugin"

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

# ---------- Marketplace manifest ----------
# .claude-plugin/marketplace.json is required for repos that act as their own
# marketplace (single-plugin repos typically do). Multi-plugin repos sometimes
# point at an external marketplace repo instead, so a missing file is a warn,
# not an err.
echo "Marketplace manifest:"
MARKETPLACE="$PLUGIN_DIR/.claude-plugin/marketplace.json"
if [[ ! -f "$MARKETPLACE" ]]; then
  warn "no .claude-plugin/marketplace.json (ok if you use an external marketplace repo)"
else
  if ! jq empty "$MARKETPLACE" >/dev/null 2>&1; then
    err "marketplace.json is not valid JSON"
  else
    ok "marketplace.json parses"
    MP_NAME=$(jq -r '.name // empty' "$MARKETPLACE")
    MP_OWNER=$(jq -r '.owner.name // empty' "$MARKETPLACE")
    MP_PLUGIN_COUNT=$(jq -r '.plugins | length // 0' "$MARKETPLACE" 2>/dev/null || echo 0)

    if [[ -z "$MP_NAME" ]]; then
      err "marketplace.json missing 'name'"
    elif [[ "$MP_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      ok "marketplace name: $MP_NAME"
    else
      err "marketplace 'name' ('$MP_NAME') is not kebab-case"
    fi

    [[ -n "$MP_OWNER" ]] && ok "marketplace owner.name: $MP_OWNER" || err "marketplace.json missing 'owner.name'"

    if [[ "$MP_PLUGIN_COUNT" -ge 1 ]]; then
      ok "marketplace has $MP_PLUGIN_COUNT plugin entry(ies)"

      MP_FIRST_SOURCE=$(jq -r '.plugins[0].source // empty' "$MARKETPLACE")
      if [[ -n "$MP_FIRST_SOURCE" ]]; then
        if [[ "$MP_FIRST_SOURCE" == "./" || "$MP_FIRST_SOURCE" == "."  || "$MP_FIRST_SOURCE" == ./* || "$MP_FIRST_SOURCE" == ../* ]]; then
          ok "plugins[0].source: $MP_FIRST_SOURCE (relative — ok for single-plugin repo)"
        else
          warn "plugins[0].source is '$MP_FIRST_SOURCE' — single-plugin repos usually use './' or a relative path"
        fi
      fi

      MP_FIRST_VERSION=$(jq -r '.plugins[0].version // empty' "$MARKETPLACE")
      if [[ -n "$MP_FIRST_VERSION" && -n "$VERSION" ]]; then
        warn "version set in BOTH plugin.json ($VERSION) and marketplace.json plugins[0].version ($MP_FIRST_VERSION) — plugin.json wins silently; remove one to avoid drift"
      fi
    else
      err "marketplace.json 'plugins' array is empty"
    fi
  fi
fi

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

# ---------- Marketing copy (Phase 5.5) ----------
# Warnings only. README quality + MARKETING.md presence don't block submission,
# but a spec-sheet README is the biggest reason good plugins don't land — flag
# obvious regressions so the human can fix before hitting "submit".
echo "Marketing copy (Phase 5.5):"
MARKETING="$PLUGIN_DIR/MARKETING.md"
if [[ -f "$MARKETING" ]]; then
  ok "MARKETING.md present"
  if ! grep -q -i '^## *Launch tweet' "$MARKETING"; then
    warn "MARKETING.md is missing a '## Launch tweet' section"
  fi
else
  warn "MARKETING.md not found — run Phase 5.5 of the create-claude-plugin skill to draft a launch tweet"
fi

if [[ -f "$README" ]]; then
  SUPPLY_MARKERS=0
  grep -q -i '^## *Before'     "$README" 2>/dev/null && SUPPLY_MARKERS=$((SUPPLY_MARKERS+1))
  grep -q -i '^## *What you'   "$README" 2>/dev/null && SUPPLY_MARKERS=$((SUPPLY_MARKERS+1))
  grep -q -i 'walk away with'  "$README" 2>/dev/null && SUPPLY_MARKERS=$((SUPPLY_MARKERS+1))
  if [[ "$SUPPLY_MARKERS" -eq 0 ]]; then
    warn "README has no supply-side markers (no '## Before', no '## What you', no 'walk away with') — reads as a spec sheet. Run Phase 5.5."
  else
    ok "README has $SUPPLY_MARKERS supply-side marker(s)"
  fi

  BANNED_HITS=$(grep -c -i -E 'simply|easily|comprehensive|everything you need|a suite of' "$README" 2>/dev/null || true)
  if [[ "$BANNED_HITS" -gt 0 ]]; then
    warn "README uses $BANNED_HITS line(s) with banned marketing words: simply / easily / comprehensive / everything you need / a suite of"
  fi
fi

# OG card — opt-in via the og-card skill. Silent if neither file exists; positive
# signal if the PNG is committed; warn if the user started a config but never
# replaced the placeholders (= rendered card would fail).
OG_PNG="$PLUGIN_DIR/assets/og.png"
OG_CONFIG="$PLUGIN_DIR/marketing/og.config.mjs"
if [[ -f "$OG_PNG" ]]; then
  OG_BYTES=$(wc -c < "$OG_PNG" | tr -d ' ')
  ok "assets/og.png present ($OG_BYTES bytes) — upload to GitHub → repo Settings → Social preview"
fi
if [[ -f "$OG_CONFIG" ]] && grep -q -E 'PLACEHOLDER|YOUR_TAGLINE|YOUR_SUBTITLE|OWNER/REPO' "$OG_CONFIG" 2>/dev/null; then
  warn "marketing/og.config.mjs has unreplaced placeholders — run og-card skill or delete the file"
fi

# ---------- Validation (Claude Code) ----------
if command -v claude >/dev/null 2>&1; then
  echo "claude plugin validate (Claude Code):"
  VALIDATE_OUT=$(mktemp -t ccp-validate.XXXXXX)
  if (cd "$PLUGIN_DIR" && claude plugin validate .) >"$VALIDATE_OUT" 2>&1; then
    ok "passes"
    VALIDATE_OK="1"
  else
    err "fails — validator output below:"
    [[ -z "$QUIET_MODE" ]] && sed 's/^/      /' "$VALIDATE_OUT" >&2
  fi
  rm -f "$VALIDATE_OUT"
else
  warn "'claude' CLI not found in PATH; skipping 'claude plugin validate'"
fi

# ---------- Cross-surface portability ----------
# Last verified against Anthropic Cowork docs: 2026-04-16
# Staleness guard: warn if these heuristics haven't been re-checked in >180 days.
# Hardcoded epoch (2026-04-16 UTC) avoids macOS/GNU `date -d` portability issues.
COWORK_VERIFIED_EPOCH=1776643200
COWORK_NOW_EPOCH=$(date +%s)
if (( COWORK_NOW_EPOCH - COWORK_VERIFIED_EPOCH > 180 * 86400 )); then
  warn "Cowork portability heuristics may be stale (last verified 2026-04-16) — re-check Anthropic docs."
fi
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

# ---------- Cowork smoke-test confirmation ----------
# Cowork has no CLI. The plugin's recommended path is Claude Code's built-in
# `computer-use` MCP driving the desktop app end-to-end. Force the human to
# confirm they've actually tested before claiming Cowork on the submission form.
echo "Cowork smoke-test (via Claude Code Computer Use):"
echo "  Re-run: $0 \"$PLUGIN_DIR\" --print-cowork-prompt"
echo "  Paste the result into an interactive Claude Code session after /mcp → enable 'computer-use'."
echo "  No macOS or no Pro/Max? Manual fallback: Claude desktop → Cowork → Customize → Browse plugins (.zip upload ok), then smoke-test."
if [[ "${COWORK_TESTED:-}" == "yes" ]]; then
  ok "COWORK_TESTED=yes — you've confirmed the smoke-test passed"
else
  warn "Cowork smoke-test NOT confirmed. Set COWORK_TESTED=yes after testing, or DO NOT select Cowork in Platforms."
fi

# ---------- Repo polish (Phase 6) ----------
# Warnings only. A plugin can submit without these, but a Phase 6 flow that
# ran publish-to-github.sh will have all of them. Flag regressions so the
# human can backfill before the submission form.
echo "Repo polish (Phase 6):"

if [[ -f "$README" ]]; then
  if grep -q -E 'img\.shields\.io/(github/package-json|badge)' "$README" 2>/dev/null; then
    ok "README has shield badges"
  else
    warn "README has no shield badges (license/version/built-for-Claude-Code) — run scripts/sync-readme.sh"
  fi
fi

HERO_FOUND=""
for hero in docs/hero.gif docs/hero.svg docs/hero.webm docs/hero.png assets/og.png; do
  [[ -f "$PLUGIN_DIR/$hero" ]] && HERO_FOUND="$hero" && break
done
if [[ -n "$HERO_FOUND" ]]; then
  ok "hero asset present: $HERO_FOUND"
else
  warn "no hero asset — run scripts/record-demo.sh (VHS → docs/hero.gif), scripts/generate-wordmark.sh (SVG fallback), or the og-card skill (assets/og.png)"
fi

# Remote repo topics — only check if we have a repo URL and gh is installed.
if [[ "$OFFLINE" != "--offline" ]] && command -v gh >/dev/null 2>&1 && [[ -n "$REPOSITORY" ]]; then
  REPO_SLUG=$(echo "$REPOSITORY" \
    | sed -E 's#^https?://github\.com/##; s#^git@github\.com:##; s#\.git$##; s#^/+##; s#/+$##')
  if [[ "$REPO_SLUG" == */* ]]; then
    REMOTE_TOPICS=$(gh repo view "$REPO_SLUG" --json repositoryTopics -q '.repositoryTopics[].name' 2>/dev/null || true)
    if [[ -z "$REMOTE_TOPICS" ]]; then
      warn "remote repo $REPO_SLUG has no topics set — run scripts/publish-to-github.sh to sync metadata"
    else
      REMOTE_TOPIC_COUNT=$(echo "$REMOTE_TOPICS" | wc -l | tr -d ' ')
      ok "remote repo has $REMOTE_TOPIC_COUNT topic(s) set"
    fi
  fi
fi

# ---------- Summary ----------
echo
echo "==> Summary: $ERRORS error(s), $WARNINGS warning(s)"

# ---------- Status mode: phase-grouped report, exit 0, skip submission handoff ----------
# Reuses all state gathered above (NAME, VERSION, EXAMPLE_LINES, VALIDATE_OK, ...).
# Emits either a table (default) or a one-line banner (--quiet for SessionStart hooks).
if [[ -n "$STATUS_MODE" ]]; then
  # --- Compute per-phase verdict ---
  # Each phase gets a status char:
  #   ✓ = complete   ⚠ = partial / unverified   ✗ = incomplete
  PHASE2_MISSING=()
  [[ ! -f "$MANIFEST"     ]] && PHASE2_MISSING+=("plugin.json")
  [[ ! -f "$README"       ]] && PHASE2_MISSING+=("README.md")
  [[ ! -f "$LICENSE_FILE" ]] && PHASE2_MISSING+=("LICENSE")
  [[ ! -f "$CLAUDE_MD"    ]] && PHASE2_MISSING+=("CLAUDE.md")
  if [[ ${#PHASE2_MISSING[@]} -eq 0 ]]; then
    PHASE2_STATUS="✓"; PHASE2_NOTE="manifest + README + LICENSE + CLAUDE.md present"
  elif [[ -f "$MANIFEST" && -f "$README" ]]; then
    PHASE2_STATUS="⚠"; PHASE2_NOTE="missing ${PHASE2_MISSING[*]}"
  else
    PHASE2_STATUS="✗"; PHASE2_NOTE="scaffold incomplete — missing ${PHASE2_MISSING[*]}"
  fi

  COMPONENT_COUNT=0
  for d in skills agents hooks monitors bin; do
    if [[ -d "$PLUGIN_DIR/$d" ]] && [[ -n "$(ls -A "$PLUGIN_DIR/$d" 2>/dev/null)" ]]; then
      COMPONENT_COUNT=$((COMPONENT_COUNT+1))
    fi
  done
  for f in .mcp.json .lsp.json settings.json; do
    [[ -f "$PLUGIN_DIR/$f" ]] && COMPONENT_COUNT=$((COMPONENT_COUNT+1))
  done
  if [[ "$COMPONENT_COUNT" -ge 1 ]]; then
    PHASE3_STATUS="✓"; PHASE3_NOTE="$COMPONENT_COUNT component type(s) wired"
  else
    PHASE3_STATUS="✗"; PHASE3_NOTE="no components — plugin is manifest-only"
  fi

  if [[ -n "$VALIDATE_OK" ]]; then
    PHASE4_STATUS="⚠"; PHASE4_NOTE="validate passed (runtime test status unknown — confirm with --plugin-dir)"
  else
    PHASE4_STATUS="✗"; PHASE4_NOTE="claude plugin validate did not pass"
  fi

  EXAMPLE_LINES_VAL="${EXAMPLE_LINES:-0}"
  if [[ -n "$EXAMPLES_BLOCK" && "$EXAMPLE_LINES_VAL" -ge 2 ]]; then
    PHASE5_STATUS="✓"; PHASE5_NOTE="README Examples section with $EXAMPLE_LINES_VAL example(s)"
  elif [[ -n "$EXAMPLES_BLOCK" ]]; then
    PHASE5_STATUS="⚠"; PHASE5_NOTE="README has Examples heading but only $EXAMPLE_LINES_VAL example line(s) — need ≥2"
  else
    PHASE5_STATUS="✗"; PHASE5_NOTE="README missing Examples section"
  fi

  # Phase 6 (Host): git remote exists; online probe optional.
  PHASE6_STATUS="✗"; PHASE6_NOTE="no git remote — not pushed yet"
  if (cd "$PLUGIN_DIR" 2>/dev/null && git remote get-url origin >/dev/null 2>&1); then
    REMOTE_URL=$(cd "$PLUGIN_DIR" && git remote get-url origin 2>/dev/null || true)
    PHASE6_STATUS="⚠"; PHASE6_NOTE="git remote set ($REMOTE_URL) — install path not yet verified"
    if [[ "$OFFLINE" != "--offline" ]] && command -v curl >/dev/null 2>&1 && [[ -n "$REPOSITORY" ]]; then
      if curl -fsI --max-time 5 "$REPOSITORY" >/dev/null 2>&1; then
        PHASE6_STATUS="✓"; PHASE6_NOTE="repo URL $REPOSITORY is reachable"
      fi
    fi
  fi

  # Phase 7 (Submit): classic mode would exit nonzero for any ERRORS; use that
  # as the submission gate signal.
  if [[ "$ERRORS" -eq 0 ]]; then
    PHASE7_STATUS="✓"; PHASE7_NOTE="all submission checks pass — ready to submit"
  else
    PHASE7_STATUS="✗"; PHASE7_NOTE="$ERRORS blocking error(s) — see trace above"
  fi

  # --- Find the first truly-blocked phase (for resume hint + quiet banner) ---
  # Quiet banner only flags ✗ (truly incomplete). ⚠ means partial/unverified
  # (e.g., validate passed but runtime test can't be detected) — nagging on
  # those every session would be noise. The full table still shows ⚠ phases.
  FIRST_BLOCKED=""
  FIRST_BLOCKED_NOTE=""
  FIRST_PARTIAL=""
  FIRST_PARTIAL_NOTE=""
  for pair in "2|$PHASE2_STATUS|$PHASE2_NOTE" "3|$PHASE3_STATUS|$PHASE3_NOTE" "4|$PHASE4_STATUS|$PHASE4_NOTE" "5|$PHASE5_STATUS|$PHASE5_NOTE" "6|$PHASE6_STATUS|$PHASE6_NOTE" "7|$PHASE7_STATUS|$PHASE7_NOTE"; do
    PH_NUM="${pair%%|*}"; REST="${pair#*|}"; PH_STATUS="${REST%%|*}"; PH_NOTE="${REST#*|}"
    if [[ "$PH_STATUS" == "✗" && -z "$FIRST_BLOCKED" ]]; then
      FIRST_BLOCKED="$PH_NUM"
      FIRST_BLOCKED_NOTE="$PH_NOTE"
    fi
    if [[ "$PH_STATUS" == "⚠" && -z "$FIRST_PARTIAL" ]]; then
      FIRST_PARTIAL="$PH_NUM"
      FIRST_PARTIAL_NOTE="$PH_NOTE"
    fi
  done

  if [[ -n "$QUIET_MODE" ]]; then
    # SessionStart hook: silence-is-golden on clean plugins. Only speak up on ✗.
    if [[ -n "$FIRST_BLOCKED" ]]; then
      command echo "create-claude-plugin: ${NAME:-<unnamed>} v${VERSION:-?} — Phase $FIRST_BLOCKED incomplete ($FIRST_BLOCKED_NOTE). Ask: 'what's left on my plugin?'"
    fi
    exit 0
  fi

  # Non-quiet status mode: report both the first blocked AND the first partial,
  # since the user asked for a full report.
  FIRST_INCOMPLETE="${FIRST_BLOCKED:-$FIRST_PARTIAL}"
  FIRST_INCOMPLETE_NOTE="${FIRST_BLOCKED_NOTE:-$FIRST_PARTIAL_NOTE}"

  cat <<EOF

================================================================
PHASE STATUS for ${NAME:-<unnamed>} v${VERSION:-?}
(7-phase model from create-claude-plugin skill)
================================================================

  Phase 2 — Scaffold        $PHASE2_STATUS  $PHASE2_NOTE
  Phase 3 — Build           $PHASE3_STATUS  $PHASE3_NOTE
  Phase 4 — Test locally    $PHASE4_STATUS  $PHASE4_NOTE
  Phase 5 — Document        $PHASE5_STATUS  $PHASE5_NOTE
  Phase 6 — Host            $PHASE6_STATUS  $PHASE6_NOTE
  Phase 7 — Submit          $PHASE7_STATUS  $PHASE7_NOTE

EOF
  if [[ -n "$FIRST_INCOMPLETE" ]]; then
    command echo "Pick up at Phase $FIRST_INCOMPLETE: $FIRST_INCOMPLETE_NOTE"
  else
    command echo "All phases complete. Run without --status to open the submission form."
  fi
  command echo "================================================================"
  exit 0
fi

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

# ---------- Automated handoff: stage clipboard + open submission form ----------
# Only runs after 0 errors (we already exited above if ERRORS>0). Goal: take the
# human out of the "copy-paste the fields and navigate to the URL" loop. We
# stage the Examples block (the longest, most annoying field) on the clipboard
# and open the submission form tab. If either tool is missing, we warn and keep
# going — this block is plumbing, not judgment.
PLATFORMS_LINE="Claude Code"
[[ "${COWORK_TESTED:-}" == "yes" ]] && PLATFORMS_LINE="Claude Code, Claude Cowork"

CLIPBOARD_PAYLOAD=$(cat <<EOF
# Paste-ready submission fields for: $NAME
# Form: $SUBMIT_URL
# The Examples block below is the big one. Other fields are short — copy from
# your terminal or re-run: ./scripts/check-submission.sh "$PLUGIN_DIR" --no-open

=== Page 2: Example use cases ===
$EXAMPLES_BLOCK

=== Page 2: Other fields ===
Plugin link:        $REPOSITORY
Plugin homepage:    ${HOMEPAGE:-}
Plugin name:        $NAME
Plugin description: $DESCRIPTION

=== Page 3: Submission details ===
Platforms:          $PLATFORMS_LINE
License type:       ${LICENSE_ID:-}
Submitter email:    ${AUTHOR_EMAIL:-}
EOF
)

if [[ -z "$NO_OPEN" && "$OSTYPE" == "darwin"* ]]; then
  echo
  echo "==> Automated handoff (macOS)"

  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$CLIPBOARD_PAYLOAD" | pbcopy
    ok "Clipboard staged: Examples block + all paste-ready fields"
  else
    warn "pbcopy not found — skipping clipboard staging"
  fi

  if command -v open >/dev/null 2>&1; then
    open "$SUBMIT_URL" >/dev/null 2>&1 && ok "Opened $SUBMIT_URL" \
      || warn "open failed — navigate to $SUBMIT_URL manually"
  else
    warn "open not found — navigate to $SUBMIT_URL manually"
  fi

  cat <<EOF

Next step:
  - Browser tab is open at the submission form.
  - Clipboard has the Examples block + other fields labeled by form page.
  - To re-stage clipboard later, run:
      ./scripts/check-submission.sh "$PLUGIN_DIR" --no-open | pbcopy
  - To skip this handoff (CI / non-interactive), pass --no-open.
EOF
elif [[ -z "$NO_OPEN" && "$OSTYPE" != "darwin"* ]]; then
  echo
  echo "Automated handoff skipped: non-macOS (\$OSTYPE=$OSTYPE). Open $SUBMIT_URL manually."
fi

# ---------- Optional: self-driving Cowork onboarding prompt ----------
# Emits a paste-ready prompt that walks the user through enabling computer-use,
# granting macOS perms, installing the plugin in Cowork, running a test prompt,
# and unlocking the Cowork gate — all from a single paste. Designed to hand-hold
# the user through every consent boundary so they finish setup instead of
# dropping off halfway.
if [[ "$PRINT_COWORK_PROMPT" == "yes" ]]; then
  # Pick a test prompt: prefer the first ">" quoted line in README's Usage section, else fallback
  TEST_PROMPT=$(awk '/^## +Usage/{flag=1; next} flag && /^## /{exit} flag' "$README" 2>/dev/null \
    | awk '/^> +"/ {sub(/^> +"/,""); sub(/"[[:space:]]*$/,""); print; exit}' )
  [[ -z "$TEST_PROMPT" ]] && TEST_PROMPT="(invoke the plugin's main skill with a realistic input)"

  ABS_PLUGIN_DIR=$(cd "$PLUGIN_DIR" && pwd)
  cat <<EOF

================================================================
COWORK SMOKE-TEST — paste into an INTERACTIVE Claude Code session
(macOS, Pro/Max, Claude Code ≥ v2.1.85)
================================================================

You are onboarding the user through a one-time Cowork smoke-test
of their plugin "${NAME}". Goal: they finish with Cowork tested —
no drop-off. Hand-hold at every step. Confirm before each consent
boundary. If a step fails twice, stop and ask — don't loop.

PLUGIN:       ${NAME}
PLUGIN PATH:  ${ABS_PLUGIN_DIR}
TEST PROMPT:  ${TEST_PROMPT}

--- Start ---
Tell the user: "I'll test ${NAME} in Cowork for you. Five steps,
~2 minutes. I'll stop at each permission gate. Ready?" Wait for
their confirmation before proceeding.

--- STEP 1: Verify Computer Use is enabled ---
Try calling mcp__computer-use__list_granted_applications.
  - Works → say "Computer Use is on." Skip to STEP 2.
  - Tool not found → say: "One-time setup, ~30 seconds. Run /mcp,
    find 'computer-use' in the list, press Enter to toggle it ON,
    then come back. I'll wait."
    When they're back, retry this step.

--- STEP 2: Grant macOS permissions ---
Call mcp__computer-use__request_access with ["Claude"].
If not granted, guide the user:
  "macOS needs two permissions for this:
     - Accessibility (so I can click and type)
     - Screen Recording (so I can take screenshots)
   Open System Settings → Privacy & Security, find each one,
   flip the Claude Code switch ON. If macOS asks you to restart
   Claude Code, do it — I'll still be here."
Take a test screenshot to confirm. Retry request_access if
needed. Don't skip — the rest of the flow depends on this.

--- STEP 3: Install the plugin in Cowork ---
Call mcp__computer-use__open_application with "Claude".
Screenshot. Find and click the Cowork tab (tell the user where
you're clicking so they can follow along).

In Cowork:
  1. Click Customize.
  2. Click Browse plugins.
  3. If "${NAME}" appears in the marketplace, click Install.
     Otherwise say: "Please zip the folder at
     '${ABS_PLUGIN_DIR}' and drag the .zip onto this window.
     I'll wait." When the upload appears, confirm install.
  4. Screenshot the installed state. Confirm "${NAME}" is listed.

--- STEP 4: Run the test prompt ---
Start a new Cowork session (screenshot → click the new-session
button). Paste (or type) this exact prompt:

  ${TEST_PROMPT}

Wait for the response. Screenshot it.

--- STEP 5: Report + unlock the gate ---
Tell the user:
  - Which skill/agent fired (or didn't)
  - Any errors observed
  - A one-line pass/fail verdict

If it PASSED, run this via the Bash tool to unlock the Cowork
checkbox on the submission form:

  COWORK_TESTED=yes ${CLAUDE_PLUGIN_ROOT:-.}/scripts/check-submission.sh "${ABS_PLUGIN_DIR}" --no-open

Then tell the user: "Cowork gate unlocked. You can check the
Cowork box on the submission form."

If it FAILED, help the user interpret the error. Offer to debug
or to leave Cowork unchecked on the submission form (that's a
valid outcome — claiming untested support is worse than passing
on the checkbox).

--- Rules ---
- Always ask before: enabling an MCP, granting access, installing,
  running the test prompt.
- If a step fails twice, stop and ask the user — don't retry blindly.
- The user can press Esc at any time to abort.
- Retention matters — if they seem confused, re-explain more slowly,
  don't bail.
================================================================
EOF
fi
