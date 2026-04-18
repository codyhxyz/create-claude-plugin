# Cowork cross-surface testing

Claude Cowork (the desktop app) shares the plugin format and official marketplace with Claude Code, but there's no CLI or `--plugin-dir` equivalent — install + test is manual via the app UI. Two paths.

## Path A — manual (any platform)

Works on macOS and Windows. Required if you're not on a Pro/Max plan or don't want to grant Computer Use permissions.

1. Open the Claude desktop app (macOS or Windows).
2. Go to the **Cowork** tab.
3. **Customize** → **Browse plugins**.
4. Either install from the marketplace (if already published) OR **upload a `.zip`** of your plugin directory.
5. Smoke-test the skill / agent / hook by triggering it in a real Cowork session.

## Path B — semi-automated via Claude Code Computer Use

Claude Code ships a built-in `computer-use` MCP server that lets Claude take screenshots and click/type on macOS GUI apps. You can hand off the entire Cowork test to it instead of doing the manual steps yourself.

**Prerequisites:**
- macOS
- Claude Pro or Max plan (not Team/Enterprise)
- Claude Code v2.1.85 or later (`claude --version`)
- Claude desktop app installed
- Interactive Claude Code session (computer-use is unavailable with the `-p` flag)

**Steps:**
1. In an interactive Claude Code session, run `/mcp`, find `computer-use`, and **Enable** it.
2. The first time it runs, grant macOS Accessibility + Screen Recording permissions when prompted.
3. Paste this prompt (or generate a pre-filled one — see below):

   > Open the Claude desktop app and switch to the Cowork tab. Click Customize → Browse plugins → upload (the file at `<absolute-path-to-your-plugin>.zip`). Once installed, run a Cowork session that triggers my plugin's main skill (e.g., the prompt: `<a-realistic-test-prompt-for-your-plugin>`). Screenshot any errors. Report whether the skill responded as expected.

4. Watch Claude Code drive the desktop app. Press `Esc` from anywhere to abort.
5. If it works: `export COWORK_TESTED=yes` and re-run `check-submission.sh`.

**Generate a pre-filled prompt** (picks up plugin name, absolute path, and a test prompt from README Usage):

```bash
./scripts/check-submission.sh /path/to/plugin --print-cowork-prompt
```

## Portability heuristics

**Likely portable** (per Anthropic's plugin docs — Cowork shares the SKILL.md format and marketplace with Code):
- Skills (`skills/<name>/SKILL.md`) ✓
- Agents (`agents/*.md`) ✓
- MCP servers (Cowork integrates external apps via MCP) — likely ✓ but verify.

**Likely Code-only** (not yet documented as Cowork-supported):
- Hooks — Cowork's event model may differ
- LSP servers — Code's code-intelligence surface
- Monitors — interactive CLI sessions
- `bin/` — modifies the Bash tool's PATH

## Submission form gate

**Don't claim Cowork support on the submission form unless you've actually tested it.** The pre-flight script (`check-submission.sh`) blocks the Cowork checkbox in the Platforms output unless you set `COWORK_TESTED=yes` to confirm you've done the manual test.
