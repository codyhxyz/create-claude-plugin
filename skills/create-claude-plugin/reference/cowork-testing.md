# Cowork cross-surface testing

Cowork (the Claude desktop app) has no CLI. Testing your plugin there means installing via the app UI and triggering your skill in a real session. **This plugin automates it end-to-end** via a headless `claude -p` subprocess that drives the desktop app through `@github/computer-use-mcp` (registered under the alias `gh-computer-use` because `computer-use` is a reserved name in Claude Code's MCP registry).

## Run it (one command)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/cowork-smoke-test.sh /path/to/your/plugin
```

Single consent gate at the top — "Proceed? [y/N]" — then everything runs unattended. The script:

1. **Verifies prereqs** — macOS, Claude Code ≥ v2.1.85, Claude desktop app installed, `jq` + `npx` available.
2. **Adds `@github/computer-use-mcp` (registered under the alias `gh-computer-use` because `computer-use` is a reserved name in Claude Code's MCP registry) at user scope** (first run only, ~30s first install via npx). Re-runs skip this.
3. **Spawns a headless `claude -p` subprocess** with `--permission-mode bypassPermissions --allowedTools "mcp__gh-computer-use__* Bash Read Write"`. The subprocess follows the autonomous prompt at `templates/cowork-autonomous-prompt.md`:
   - Opens Claude desktop
   - Navigates to Cowork → Customize → Browse plugins
   - Installs your plugin (from the marketplace, or by zipping the plugin dir and dragging the zip in if it's pre-publish)
   - Starts a new Cowork session
   - Types the test prompt (auto-detected from your README's Usage section — first quoted line — or passed via `--test-prompt "..."`)
   - Waits 60s for Claude's response
   - Evaluates PASS/FAIL
4. **On PASS** — re-runs `check-submission.sh` with `COWORK_TESTED=yes` so the Cowork checkbox unlocks on the submission form.
5. **On FAIL** — prints the last 40 lines of subprocess output and exits 1. Cowork gate stays closed; you claim Code only.

Timing budget: 2–3 min wall clock. Stay away from the keyboard during the run; mouse movement can fight the automation.

## First-run permissions (macOS)

macOS requires you to grant **Claude.app** two permissions before any automation can click/type/screenshot:

- **Accessibility** (System Settings → Privacy & Security → Accessibility)
- **Screen Recording** (System Settings → Privacy & Security → Screen Recording)

No script can bypass this — macOS's TCC database only flips on explicit user consent. The first run of `cowork-smoke-test.sh` will fail partway through if the permissions aren't already granted. Grant them once, re-run, and subsequent runs work without touching System Settings.

## Override the test prompt

```bash
./scripts/cowork-smoke-test.sh ./my-plugin --test-prompt "Your specific trigger phrase here"
```

Useful when your README Usage section doesn't include a paste-ready trigger, or when you want to test a specific skill's activation path.

## Non-interactive / CI mode

```bash
./scripts/cowork-smoke-test.sh ./my-plugin --yes
```

Skips the confirmation prompt. Everything else (including MCP add + macOS permissions) still runs. If the macOS grants aren't in place, the test fails — there is no "auto-grant Accessibility" flag, by design.

## Fallback: no macOS or no Pro/Max

Install manually: Claude desktop → **Cowork** tab → **Customize** → **Browse plugins** → install from the marketplace (if published) or upload a `.zip`. Trigger your main skill in a Cowork session yourself. Same gate: `COWORK_TESTED=yes` only after you've actually done it. You can set it yourself: `COWORK_TESTED=yes ./scripts/check-submission.sh ./my-plugin --no-open`.

## What's in the `computer-use` MCP

`@github/computer-use-mcp` (registered under the alias `gh-computer-use` because `computer-use` is a reserved name in Claude Code's MCP registry) is GitHub's open-source MCP server (published on npm). It exposes tools for:
- `open_application` — launch apps
- `screenshot` / `screenshot_region` — visual inspection
- `click` / `double_click` / `right_click` — mouse
- `type_text` — keyboard
- `drag_and_drop` — for file uploads
- `request_access` / `list_granted_applications` — TCC permission probe

We don't own the MCP — we compose it. If it breaks or changes, file issues at `github/computer-use-mcp`, not here.

## Portability heuristics

Cowork shares the SKILL.md format and marketplace with Claude Code (per Anthropic's plugin docs).

**Likely portable:**
- Skills (`skills/<name>/SKILL.md`) ✓
- Agents (`agents/*.md`) ✓
- MCP servers — likely ✓ but verify

**Likely Code-only:**
- Hooks — Cowork's event model may differ
- LSP servers — Code's code-intelligence surface
- Monitors — interactive CLI sessions
- `bin/` — modifies the Bash tool's PATH

## Submission form gate

`check-submission.sh` blocks the Cowork checkbox in the Platforms output unless `COWORK_TESTED=yes` is set. `cowork-smoke-test.sh` flips that gate automatically on PASS; you don't need to set it manually unless you did the test via the manual fallback path.
