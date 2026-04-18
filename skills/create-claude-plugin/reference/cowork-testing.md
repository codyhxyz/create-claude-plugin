# Cowork cross-surface testing

Cowork (the Claude desktop app) has no CLI. Testing your plugin there means installing via the app UI and triggering your skill in a real session.

**This plugin automates it end-to-end.** Claude Code's built-in `computer-use` MCP drives the desktop app for you: installs the plugin, opens a Cowork session, runs your test prompt, screenshots any errors, reports back.

## Run it

**Prerequisites:**
- macOS
- Claude Pro or Max plan
- Claude Code v2.1.85+ (`claude --version`)
- Claude desktop app installed
- Interactive Claude Code session (not `-p`)

**One command:**

```bash
./scripts/check-submission.sh /path/to/your/plugin --print-cowork-prompt
```

Paste the printed prompt into an interactive Claude Code session. The prompt is a self-driving onboarding script — it walks you through every step, stopping for your permission at each consent boundary:

1. **Verifies `computer-use` is enabled.** If not, tells you exactly what to do (`/mcp` → toggle ON). Waits until you confirm.
2. **Requests macOS permissions.** Triggers Accessibility + Screen Recording prompts. Guides you through System Settings if macOS doesn't auto-prompt. Won't move on until granted.
3. **Installs your plugin in Cowork.** Opens the Claude desktop app, switches to the Cowork tab, navigates Customize → Browse plugins, and installs from the marketplace (or asks you to drop the `.zip` if you're pre-publish).
4. **Runs your test prompt.** Starts a Cowork session, pastes a realistic prompt from your README's Usage section, screenshots the response.
5. **Unlocks the submission gate.** If the smoke-test passes, the onboarding sets `COWORK_TESTED=yes` and re-runs `check-submission.sh` for you. If it fails, it helps you debug or confirms that leaving Cowork unchecked is the right call.

Press `Esc` at any point to abort.

## Fallback: no macOS or no Pro/Max

Install manually: Claude desktop → **Cowork** tab → **Customize** → **Browse plugins** → install from the marketplace (if published) or upload a `.zip`. Trigger your main skill in a Cowork session yourself. Same gate: `COWORK_TESTED=yes` only after you've actually done it.

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

`check-submission.sh` blocks the Cowork checkbox in the Platforms output unless `COWORK_TESTED=yes` is set. Don't claim Cowork support you haven't verified.
