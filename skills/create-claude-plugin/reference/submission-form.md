# Official Marketplace Submission Form Reference

Submit at one of:
- **https://claude.ai/settings/plugins/submit**
- **https://platform.claude.com/plugins/submit**

Once approved, your plugin lands in `anthropics/claude-plugins-official` and is installable as `/plugin install <name>@claude-plugins-official` for everyone.

## Before opening the form (executing model: run this via Bash tool)

The executing model invokes the pre-flight script directly — the human does not open a terminal. It extracts every field from the plugin's `plugin.json` + `README.md`, verifies they're complete, and prints them in paste-ready format:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"
```

If anything is missing or malformed, fix it before opening the form. The form has no draft-save — you don't want to be hunting for fields mid-submission.

## Automated handoff (macOS)

After a clean pre-flight (0 errors), `check-submission.sh` automatically:
- copies the Examples block + all paste-ready fields (grouped by form page) to the clipboard via `pbcopy`,
- opens `https://claude.ai/settings/plugins/submit` in the default browser via `open`.

So the scripted Phase 7 flow is: **model runs script → browser opens → model asks `AskUserQuestion` → user confirms → paste-tab through the form**. The human watches output and responds to `AskUserQuestion`; they don't shell out. See `reference/phase7-handoff.md` for the exact wording and options.

Pass `--no-open` (or set `CCP_NO_OPEN=1`) to skip the clipboard + browser step for CI / non-interactive use. If `pbcopy` or `open` are missing, the script warns and continues — it never hard-fails on the handoff.

## Form fields by page

### Page 1 — Account / submitter

Likely auto-filled from your Anthropic login. (If you encounter additional fields here, add them to this doc.)

### Page 2 — Plugin links + details

| Field | Required | Source | Notes |
|---|---|---|---|
| **Plugin link** | yes | `plugin.json` → `repository` | URL to your repo |
| **Plugin homepage** | no | `plugin.json` → `homepage` | Optional docs URL; often the README |
| **Plugin name** | yes | `plugin.json` → `name` | kebab-case; not taken; no unowned brand names |
| **Plugin description** | yes | `plugin.json` → `description` | One concise sentence about what it does |
| **Example use cases** | yes | README `## Examples` (or `## Example use cases`) section | Format: `Example 1: ...\nExample 2: ...` |

**Name constraints** (canonical rules in `reference/marketplace-manifest.md` § Reserved marketplace names):
- Must be kebab-case, not reserved, not impersonating Anthropic
- Should be available — check the official marketplace.json for collisions:
  ```bash
  curl -s https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json | jq -r '.plugins[].name'
  ```
- If your name is taken, rename in `plugin.json` AND your repo before submitting

**Description guidance:**
- Concise — one sentence, leads with the verb
- Describes what users get, not how it works internally
- Avoid hype words ("revolutionary", "powerful")
- Match the description in your `plugin.json` (so the UI is consistent post-install)

**Examples format:**
The form expects narrative examples, not bullet lists. Two or three is plenty. Each should be:
- A real user prompt (not a description of one)
- Concrete — names a tool, file type, or scenario

Bad: `Example 1: Use this for code review`
Good: `Example 1: "Review this auth module for security issues" — the plugin walks the codebase top-down (WHY → WHAT → HOW) and surfaces architectural risks before nitpicks.`

### Page 3 — Submission details

| Field | Required | Source | Notes |
|---|---|---|---|
| **Platforms** | yes | (your testing) | Multi-select. Known options: **Claude Code** (CLI) and **Claude Cowork** (desktop app). Possibly more — exact options aren't documented; check the form. |
| **License type** | no | `LICENSE` file / `plugin.json` → `license` | `MIT`, `Apache-2.0`, `proprietary`, etc. |
| **Privacy policy URL** | conditional | (you) | Required if your plugin collects/transmits user data. Skip if not applicable. |
| **Submitter email** | yes | (your contact) | Anthropic uses this for review communications |

**Privacy policy:** If your plugin includes hooks/MCP/monitors that send user data anywhere external (analytics, telemetry, your own server), you need a privacy policy. Pure-skill plugins with no network calls don't.

**Platforms — Claude Code vs Claude Cowork:** Both share the same plugin format (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`, etc.) and the same official marketplace. The difference is the install/test surface:

| Surface | Install | Automated test? | What's known to work |
|---|---|---|---|
| **Claude Code** | `/plugin install <name>@<marketplace>` or `claude --plugin-dir <path>` for local | Yes — `claude plugin validate`, `--plugin-dir` smoke test | All component types |
| **Claude Cowork** | Desktop app → Cowork tab → Customize → Browse plugins → Install or upload `.zip` | **No CLI; manual UI only** | Skills + agents documented; hooks/LSP/monitors/`bin/` likely Code-only |

**Don't claim Cowork in Platforms unless you've actually opened the desktop app and verified your plugin works there.** The pre-flight script (`check-submission.sh`) only adds Cowork to the suggested Platforms output when you set `COWORK_TESTED=yes` — that env var is the human's signed statement that they did the manual test.

## Review process

- No public timeline
- Reviewed for **quality** (well-documented, functional, reliable) and **security**
- No public rubric beyond those categories
- Once approved, listed at https://claude.com/plugins and `/plugin discover`

## After approval

Once your plugin is in `claude-plugins-official`, your CLI can prompt users to install it via plugin hints (see `/en/plugin-hints` in the official Claude Code docs).

## If your submission is rejected

Anthropic will email you. Common rejection causes (extrapolated from quality requirements):
- Insufficient documentation (no README, no examples)
- Plugin doesn't actually work as described
- Security concerns (executes untrusted code, lax `${CLAUDE_PLUGIN_ROOT}` usage, suspicious MCP server behavior)
- Name collision or brand violation
- Missing `LICENSE`

Fix the cited issues, bump your version, and re-submit.

## Alternative if you don't want to submit

You don't have to be in the official marketplace. Anyone can install your plugin from your GitHub repo via:

```
/plugin marketplace add owner/repo
/plugin install plugin-name@<marketplace-name>
```

Some community plugins live exclusively in self-hosted marketplaces. The official store is for discoverability and one-line install — not a prerequisite to existing.
