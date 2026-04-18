---
name: create-claude-plugin
description: Use when the user wants to create, package, publish, resume mid-development, or check the status of a Claude Code plugin — including converting a personal `.claude/` config into a shareable plugin, adding a marketplace, hosting on GitHub, submitting to the official Anthropic plugin marketplace, picking up a plugin scaffolded in an earlier session, or shipping an update to an already-published plugin. Triggers on phrases like "make a Claude plugin", "package this skill", "publish to the Claude store", "claude-plugin-official", "/plugin marketplace add", "what's left on my plugin", "plugin status", "am I ready to submit", "resume my plugin", "ship an update", or any request to scaffold, develop, distribute, or submit a Claude Code plugin.
---

# Create a Claude Code Plugin (end-to-end)

## Overview

A Claude Code plugin is a self-contained directory with a `.claude-plugin/plugin.json` manifest plus any combination of skills, agents, hooks, MCP servers, LSP servers, monitors, output styles, executables, and default settings. This skill walks the user from "I have an idea" → "it's installable from my GitHub repo" → "it's in Anthropic's official marketplace at `claude-plugins-official`."

**Core principle:** Lean on `claude plugin validate` and the included `check-submission.sh` script for *checks*. Use this skill for *judgment* — naming, scoping, deciding between standalone vs. plugin, writing a good description, picking the right component type. The CLI tools tell you when something is *broken*; this skill helps you decide what to *build*.

## When to use

- User says "make a Claude plugin" / "package this as a plugin" / "publish to the store"
- User has a `.claude/` directory and wants to convert it to a distributable plugin
- User wants to scaffold a new plugin from scratch
- User wants to add a marketplace.json so their repo is installable via `/plugin marketplace add`
- User is ready to submit to `claude-plugins-official`
- User wants to ship an **update** to an already-published plugin (see Phase 0)
- User is **resuming mid-development** on a plugin scaffolded in a prior session — "what's left", "status", "am I ready to submit" (see Phase 0)

**When NOT to use:**
- Personal-only customization with no intent to share → use `~/.claude/` directly. Plugins add namespacing overhead (`/my-plugin:hello` instead of `/hello`); skip them for solo work.
- Editing an existing skill's content (no plugin shape changes) → just edit it.

## The seven phases

Run them in order. Each phase has a deliverable. Don't skip — phase N's output is phase N+1's input.

| # | Phase | Deliverable |
|---|---|---|
| 0 | **Existing plugin?** | If so, skip scaffolding — branch into the resume-or-update flow |
| 1 | **Decide** | Plugin or standalone? Which components? |
| 2 | **Scaffold** | Directory + `plugin.json` + `marketplace.json` + LICENSE + README stub |
| 3 | **Build** | Skills/agents/hooks/etc. wired in correct locations |
| 4 | **Test locally** | `claude --plugin-dir <path>` + `/reload-plugins` + `claude plugin validate .` all green |
| 5 | **Document** | README with install + usage + examples; CHANGELOG with v0.1.0 |
| 5.5 | **Draft marketing copy** | Supply-side README (replaces Phase 5 stub) + `MARKETING.md` with launch tweet |
| 6 | **Host & make installable** | Push to GitHub; verify `/plugin marketplace add owner/repo` works |
| 7 | **Submit to official store** | Run `check-submission.sh`, fill the form |

---

## Phase 0: Is this an existing plugin?

If the user already has a `.claude-plugin/plugin.json` in the target directory, **skip Phases 1–3** and branch based on state:

### 0a — Resume mid-development (scaffolded, not yet published)

Signs you're here: no git remote, or repo exists but plugin is not yet on `claude-plugins-official`. The user is asking *"what's left"*, *"what's my status"*, *"am I ready to submit"*, or just picking up work from a prior session.

**Get a phase-grouped status report** — this is the only step that matters at the top of Phase 0a:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>" --status
```

The `--status` mode is tolerant of incomplete state (exit 0 even with gaps) and groups output by the 7 phases. Read the output, pick up from the **first incomplete phase**, and continue forward. Don't restart Phase 1 or Phase 2 — the scaffolding already ran.

If the user's CLAUDE.md is missing from the plugin root, add it (Phase 2's copy list includes it now) — that file is what future sessions will read to stay grounded in the project's rules.

### 0b — Update an already-published plugin

Signs you're here: the plugin already appears on **https://claude.ai/settings/plugins** (the authoritative submissions dashboard) OR the user says "ship an update" / "release v0.X.Y".

**How Anthropic tracks submissions.** The authoritative status lives at `claude.ai/settings/plugins` (auth-gated). Each entry shows a status badge (`Published`, review states, etc.) but **no version column and no sync button** — updates are manual re-submissions, not repo-auto-pulls. The public file at `anthropics/claude-plugins-official/.claude-plugin/marketplace.json` is a curated subset and is NOT a reliable status signal; `check-submission.sh` now reports public-snapshot absence as *inconclusive*.

1. **Bump `version`** in `.claude-plugin/plugin.json` per semver (patch = fix, minor = new feature, major = breaking). Set in only one place — `plugin.json` always wins over `marketplace.json` silently.
2. **Add a CHANGELOG entry** at the top of `CHANGELOG.md`: new version heading, today's date (`date +%Y-%m-%d`), summary of changes. Keep the prior entries; don't rewrite history.
3. **Re-run validation + pre-flight:**
   ```bash
   claude plugin validate <plugin-path>
   ${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"
   ```
4. **Push the update.** Commit, tag the new version (`git tag v<x.y.z> && git push --tags`), and push. Users running `/plugin install` will pick up the new version on refresh.
5. **Re-submit via the dashboard.** Go to https://claude.ai/settings/plugins → click **New submission** → paste the pre-flight's staged fields → submit. Anthropic reviews the new version as a separate submission; repo-auto-pull does not happen.

Both sub-phases skip scaffolding + component decisions but still go through Phases 4 (test), 5 (doc), 6 (host), and 7 (submit, if applicable).

---

## Phase 1: Decide

Before building anything, answer two questions.

**Q1: Does this need to be a plugin?**

| Use case | Right form |
|---|---|
| Personal workflow, single project | Standalone `.claude/` (skip this skill) |
| Sharing across teammates / community / multiple projects | Plugin |
| Versioned releases | Plugin |
| Distribution via marketplace | Plugin |

**Q2: Which components?** A plugin can include any of:

- **Skills** (`skills/<name>/SKILL.md`) — model-invoked instructions; Claude reads them when the description matches the task
- **Agents** (`agents/<name>.md`) — specialized subagents the main agent can delegate to
- **Hooks** (`hooks/hooks.json`) — event handlers (PostToolUse, SessionStart, etc.) that run shell commands
- **MCP servers** (`.mcp.json`) — external tool servers exposed to Claude
- **LSP servers** (`.lsp.json`) — language servers for real-time code intelligence
- **Monitors** (`monitors/monitors.json`) — background processes that stream notifications into the session
- **Executables** (`bin/`) — binaries added to the Bash tool's `PATH`
- **Default settings** (`settings.json`) — apply when the plugin is enabled (only `agent` and `subagentStatusLine` keys supported)

Most plugins are one or two of these. **Pick the smallest set that solves the actual problem.** Read `reference/component-types.md` if unsure which fits.

---

## Phase 2: Scaffold

Create the directory structure. Component dirs (`skills/`, `agents/`, `hooks/`, etc.) live at the **plugin root**, NOT inside `.claude-plugin/` — only `plugin.json` and `marketplace.json` go there. See `reference/component-types.md` for why.

Correct shape:

```
my-plugin/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json    # makes the repo a single-plugin marketplace
├── skills/                 # at root, NOT inside .claude-plugin/
├── agents/                 # at root
├── CLAUDE.md               # project-local rules — auto-read by every session
├── README.md
├── LICENSE
├── CHANGELOG.md
└── .gitignore
```

Copy from `templates/`:
- `templates/plugin/plugin.json` → `.claude-plugin/plugin.json` (fill in name, description, author, repo URL)
- `templates/plugin/marketplace.json` → `.claude-plugin/marketplace.json`
- `templates/plugin/README.md` → `README.md`
- `templates/plugin/LICENSE` → `LICENSE` (MIT; update year + name)
- `templates/plugin/CHANGELOG.md` → `CHANGELOG.md`
- `templates/plugin/.gitignore` → `.gitignore`
- `templates/plugin/CLAUDE.md` → `CLAUDE.md` at the **plugin root** (replace the `PLUGIN_NAME` placeholder on line 1). This file is what every future session in the repo reads automatically — it's how the plugin's standards survive across days and sessions without the user re-invoking this skill. Do not skip it.
- `templates/plugin/.github/` → `.github/` (issue forms, PR template, `CONTRIBUTING.md`). Substitute `PLUGIN_NAME` and `YOUR_GH_USER` in `CONTRIBUTING.md`.
- `templates/plugin/docs/demo.tape` → `docs/demo.tape`. Customize the middle block for your demo; render later with `${CLAUDE_PLUGIN_ROOT}/scripts/record-demo.sh` to produce `docs/hero.gif`.

**Naming:** Name must be kebab-case and not reserved or Anthropic-impersonating. See `reference/marketplace-manifest.md` § "Reserved marketplace names" for the full list. Skills are namespaced `/<plugin-name>:<skill-name>` — pick a name that reads well there.

For full schema details: `reference/plugin-manifest.md` and `reference/marketplace-manifest.md`.

---

## Phase 3: Build

Add components using the templates in `templates/` as starting points:

- **Skill:** `templates/skill/SKILL.md` → `skills/<your-skill-name>/SKILL.md`. Required frontmatter: `description` (when to use, third person, "Use when...", no workflow summary). Optional: `disable-model-invocation: true` if it should only fire on explicit slash command.
- **Agent:** `templates/agent/agent.md` → `agents/<your-agent-name>.md`. Frontmatter supports `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation`. **Not supported in plugin agents:** `hooks`, `mcpServers`, `permissionMode`.
- **Hook:** `templates/hook/hooks.json` → `hooks/hooks.json`. Use `${CLAUDE_PLUGIN_ROOT}` to reference scripts inside the plugin.
- **MCP server:** Inline in `plugin.json` under `mcpServers`, or a `.mcp.json` at the plugin root. Same `${CLAUDE_PLUGIN_ROOT}` rule.
- **LSP server / Monitor:** See `reference/component-types.md`.

**Use `${CLAUDE_PLUGIN_ROOT}` in all hook / MCP / monitor commands and args** — plugins run from a cache, so absolute paths + `..` don't work. For state that should survive updates, use `${CLAUDE_PLUGIN_DATA}`. Full rules: `reference/plugin-manifest.md` § "Environment variables". Make hook scripts executable (`chmod +x`).

For each component type's full reference: `reference/component-types.md`.

---

## Phase 4: Test locally

Test on **every surface you plan to claim support for** in the submission form. Plugins target two surfaces today: **Claude Code** (CLI, fully scriptable) and **Claude Cowork** (desktop app, manual UI install only — no `--plugin-dir` equivalent).

### 4a — Claude Code (automated)

The `--plugin-dir` flag loads a plugin without installing it. The local copy takes precedence over installed versions for that session.

```bash
claude --plugin-dir ./my-plugin
```

Inside the session:
- `/help` — your plugin's skills should appear under the `<plugin-name>:` namespace
- `/agents` — your agents should be listed
- Try invoking each skill: `/<plugin-name>:<skill-name>`
- After editing files: `/reload-plugins` (no restart needed)

Run validation:

```bash
claude plugin validate .
```

Common issues: components inside `.claude-plugin/` (move up to root), hook script not executable (`chmod +x`), hook command uses absolute path (switch to `${CLAUDE_PLUGIN_ROOT}/...`), skill frontmatter missing `description`. For debugging recipes: `reference/component-types.md` § Troubleshooting.

### 4b — Claude Cowork

Cowork has no CLI. This plugin drives the desktop app end-to-end via a headless `claude -p` subprocess using `@github/computer-use-mcp`. Prereqs: macOS, Pro/Max, Claude Code v2.1.85+, Claude desktop app installed.

**One command, one consent gate, unattended after that:**

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/cowork-smoke-test.sh "<plugin-path>"
```

The script:
1. Confirms the plan in one prompt (`Proceed? [y/N]`) listing the MCP it'll install and the subprocess it'll spawn.
2. First-run only: `claude mcp add computer-use --scope user -- npx -y @github/computer-use-mcp` (~30s).
3. Spawns `claude -p` with `--permission-mode bypassPermissions --allowedTools "mcp__computer-use__* Bash Read Write"` and feeds it the autonomous prompt at `templates/cowork-autonomous-prompt.md`. That subprocess installs the plugin in Cowork, runs the test prompt from your README's Usage section, and emits `COWORK_TEST_RESULT: PASS` or `FAIL` on stdout.
4. On PASS: re-runs `check-submission.sh` with `COWORK_TESTED=yes` — gate unlocked, Cowork checkbox free.
5. On FAIL: prints the subprocess tail and exits non-zero. Claim Code only.

**First-run macOS permissions:** Claude.app needs Accessibility + Screen Recording via System Settings → Privacy & Security. macOS won't let any script bypass this; click once and subsequent runs are silent.

**Override the test prompt** with `--test-prompt "..."` if your README doesn't have a paste-ready trigger. **Skip the consent** with `--yes` for CI re-runs.

Full flow + manual fallback for non-macOS / Free users: `reference/cowork-testing.md`. Legacy interactive flow (via `check-submission.sh --print-cowork-prompt`) is still supported for multi-step learners but the one-command path is the default.

---

## Phase 5: Document

The README is the primary install/usage doc. Use `templates/plugin/README.md` and fill in:

- **What it is** — one-sentence elevator pitch
- **What it does** — 2–4 bullets, concrete
- **Installation** — both `/plugin marketplace add` flow AND manual install
- **Usage** — at minimum one example invocation per skill/agent
- **Example interactions** — a real before/after; this is what convinces people the plugin is worth installing

Bump `version` in `plugin.json` (start at `0.1.0`).

**CHANGELOG:** Add a `v0.1.0` entry. The copied template contains a `YYYY-MM-DD` placeholder — the executing model must replace it with today's date. Use `date +%Y-%m-%d` (or equivalent) and write the result into `CHANGELOG.md`. Don't leave the placeholder in.

**For the submission form**, your README needs an "## Examples" or "## Example use cases" section — `check-submission.sh` looks for it.

What you write here is a utilitarian template-fill — it'll pass validation but it reads like a spec sheet. **Phase 5.5 will upgrade it to supply-side copy** before the GitHub push, so don't agonize over wording in this phase.

---

## Phase 5.5: Draft marketing copy

Between documentation and hosting, draft marketing-grade copy. A README that reads as a spec sheet is the single biggest reason good plugins don't land. Run this by default; let the user opt out.

**Load `reference/marketing-copy.md` before drafting.** It covers supply-side principles, anti-patterns (no "comprehensive", no "simply", no emoji headers), and the tagline + tweet rubrics. Don't draft without it.

### Steps

1. **Read the plugin's current state** — `.claude-plugin/plugin.json`, the component list, and the example interactions written in Phase 5. You need these to ground the copy in what the plugin actually does.
2. **Draft a supply-side README.** Required sections in order:
   - **Tagline** — one sentence under the title, category + unique move, no superlatives
   - **Before → After** — concrete, user-voiced. Quoted pain in Before; chained end-states in After
   - **What you walk away with** — outcomes, not artifacts. If a bullet names a filename, rewrite it as a result
   - **Demo** — placeholder ok. Customize the scaffolded `docs/demo.tape` and run `${CLAUDE_PLUGIN_ROOT}/scripts/record-demo.sh` to produce `docs/hero.gif`. If VHS isn't installed, the script falls back to `scripts/generate-wordmark.sh` (SVG). Flag with `<!-- TODO: demo GIF — see docs/demo.tape -->` if you're deferring.
   - **Examples** — real before/after scenarios (keep or adapt the Phase 5 examples)
   - **Install**
   - **Usage**
   - **Why this exists** — the unmet need; what the plugin *won't* do
3. **Draft a launch tweet** (≤280 chars): hook in first 10 words, one concrete outcome, one link, no hashtag spam, max 1 emoji. Use `@you` as a placeholder for the author handle — don't ask the user for theirs; that's feature creep.
4. **Optionally draft 2–3 alt tweets** with different hooks.
5. **Present both via `AskUserQuestion`** with four options:
   - *"Ship as-is"* — write README to plugin root (overwriting the Phase 5 template-fill), copy `templates/plugin/MARKETING.md` to plugin root and fill in `## Launch tweet` + `## Alt tweets`
   - *"Revise"* — take free-text feedback, regenerate, re-present. Cap at 3 rounds; after the 3rd, ship whatever's current
   - *"Draft og-card now"* — ship the README + tweet, then **invoke the `og-card` skill** to generate a 1200×630 social-preview PNG at `<plugin>/assets/og.png`. Returns here on completion
   - *"Skip"* — keep the Phase 5 template-fill README, don't create `MARKETING.md`, continue to Phase 6
6. **Before writing: grep the draft for banned strings** — `simply`, `easily`, `comprehensive`, `everything you need`, `a suite of`. If any appear, rewrite before presenting to the user.

### If a README already exists (update flow or pre-populated)

Don't auto-overwrite. Present the draft **alongside a diff and the reasoning**: which supply-side markers are missing in the existing README, which outcomes aren't surfaced, why the new tagline is stronger. User decides whether to accept, merge selectively, or reject. Make the case; the user makes the call.

### Non-goals for this phase

- Posting the tweet — output is a draft, user ships it
- Storing the user's Twitter handle — `@you` stays as a placeholder
- Show HN / Product Hunt / Reddit post drafts — out of scope
- More than 3 alt tweets

OG-card generation is opt-in via the *"Draft og-card now"* option; it delegates to the `og-card` sibling skill.

---

## Phase 6: Host & make installable

Push to GitHub using the helper script (idempotent — safe to re-run on updates):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/publish-to-github.sh "<plugin-path>"
```

The script reads `.claude-plugin/plugin.json` as the single source of truth. In one idempotent pass it:

1. Creates the repo (or pushes the current branch if it already exists).
2. Runs `gh repo edit` to sync description, homepage, and topics. Topics = baseline (`claude-code`, `claude-code-plugin`, `claude-plugin`) + auto-detected from layout (`skills/` → `claude-skill`, `agents/` → `claude-agent`, `hooks/` → `claude-hook`, `.mcp.json` → `mcp`) + manifest `keywords`.
3. Tags `v<version>` and cuts a GitHub release from the matching `CHANGELOG.md` entry (skip with `CCP_SKIP_RELEASE=1`).
4. Opens or refreshes a PR against `codyhxyz/claude-plugins` adding this plugin to the meta-marketplace, so users `/plugin marketplace add codyhxyz/claude-plugins` once and install any listed plugin (skip with `CCP_SKIP_REGISTRY=1`; override registry with `CCP_REGISTRY_REPO=owner/repo`).

Once pushed, anyone can install with:

```
/plugin marketplace add <owner>/<repo>
/plugin install <plugin-name>@<marketplace-name>
```

Where `<marketplace-name>` is the `name` in your `.claude-plugin/marketplace.json`.

Other hosting options (GitLab, Bitbucket, npm, git URL, git-subdir) are documented in `reference/hosting-options.md`.

**Verify the install flow before submitting to the store:** in a fresh Claude Code session, run `/plugin marketplace add <owner>/<repo>` and `/plugin install`. If it doesn't work for you, it won't work for anyone.

---

## Phase 7: Submit to the official store (optional)

The official Anthropic marketplace is `claude-plugins-official`. Once accepted, your plugin is installable as `/plugin install <name>@claude-plugins-official`.

The submission form is a human step — no public API. But everything up to clicking "Submit" is automated. **Full protocol in `reference/phase7-handoff.md`** — read it once at the start of Phase 7. Short version:

1. **Executing model runs the pre-flight via Bash tool** (not the human in a terminal):
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"
   ```
   On macOS with 0 errors, the script stages the clipboard + opens the form tab.
2. **Confirm with `AskUserQuestion`**, not free text. Single yes/no: *"Ready to submit `<plugin-name>`?"* Options: `Yes — opening form now` / `No — I'll do it later`. Ask once.
3. **On "Yes", present paste-ready fields grouped by form page** using the script's Page 2 / Page 3 groupings verbatim. Don't reorder.
4. **Platforms field — never claim Cowork** unless `COWORK_TESTED=yes` was set before running the script.
5. **After the user submits, stop.** No polling, no timeline.

Submit at **https://claude.ai/settings/plugins/submit** (or **https://platform.claude.com/plugins/submit**). For the form fields in detail: `reference/submission-form.md`. For the full handoff protocol with `AskUserQuestion` option text: `reference/phase7-handoff.md`.

---

## Quick reference

| Task | Command |
|---|---|
| Test locally | `claude --plugin-dir ./my-plugin` |
| Reload after edit | `/reload-plugins` (inside Claude Code) |
| Validate | `claude plugin validate .` |
| Install from a local marketplace | `/plugin marketplace add ./my-plugin` |
| Install from GitHub | `/plugin marketplace add owner/repo` |
| Publish to GitHub (idempotent) | `${CLAUDE_PLUGIN_ROOT}/scripts/publish-to-github.sh "<plugin-path>"` |
| Sync README badges + install block from `plugin.json` | `${CLAUDE_PLUGIN_ROOT}/scripts/sync-readme.sh "<plugin-path>"` |
| Record hero GIF (VHS; falls back to SVG wordmark) | `${CLAUDE_PLUGIN_ROOT}/scripts/record-demo.sh "<plugin-path>"` |
| Pre-flight the submission (model invokes via Bash) | `${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"` |
| Cowork smoke-test (end-to-end automated) | `${CLAUDE_PLUGIN_ROOT}/scripts/cowork-smoke-test.sh "<plugin-path>"` |
| Submit to official store | https://claude.ai/settings/plugins/submit |

## Common mistakes

| Mistake | Fix |
|---|---|
| Components inside `.claude-plugin/` | Move them to the plugin root. See `reference/component-types.md`. |
| Hook command uses absolute path or `..` | Use `${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh`. See `reference/plugin-manifest.md`. |
| Plugin works locally but not after install | Plugins are copied to a cache. Files outside the plugin dir aren't copied. Use symlinks or restructure. |
| Skill description summarizes the workflow | Description should be **when to use**, not **what it does**. The skill body is for the workflow. |
| Plugin name in PascalCase or with spaces | Kebab-case only. See `reference/marketplace-manifest.md`. |
| Version bumped in `plugin.json` AND `marketplace.json` | Set in only one place — `plugin.json` always wins silently. |
| Bumped code without bumping version | Existing users won't see updates due to caching. Always bump the version when you change behavior. |
| Tried to use `hooks` / `mcpServers` / `permissionMode` in a plugin agent | Not supported in plugin agents (security restriction). |
| Reserved or impersonating name | See `reference/marketplace-manifest.md` § Reserved marketplace names. |
| No `CLAUDE.md` at the plugin root | Copy `templates/plugin/CLAUDE.md` in. Without it, sessions opened in the plugin dir after scaffolding day lose all project grounding — Claude won't know the directory invariants, path rules, or manifest rules. |

## Red flags — you're doing it wrong

- Components under `.claude-plugin/` instead of the plugin root
- Plugin has zero components (only a manifest)
- Hand-writing JSON without running `claude plugin validate`
- Opening the submission form without running `check-submission.sh` via the Bash tool first
- Using brand names you don't own
- Submitting without verifying the actual install path (`/plugin marketplace add`)

## Reference index

| File | Load when |
|---|---|
| `reference/plugin-manifest.md` | Filling out `plugin.json` (full schema, `${CLAUDE_PLUGIN_ROOT}` rules) |
| `reference/marketplace-manifest.md` | Building `marketplace.json`; reserved-name + kebab-case rules |
| `reference/component-types.md` | Picking a component type, debugging, or confirming root-vs-`.claude-plugin/` layout |
| `reference/hosting-options.md` | Hosting somewhere other than GitHub |
| `reference/marketing-copy.md` | Phase 5.5 — drafting supply-side README + launch tweet; anti-pattern list |
| `../og-card/SKILL.md` | Phase 5.5 option *"Draft og-card now"* — interview + render 1200×630 social-preview PNG |
| `reference/cowork-testing.md` | Phase 4b — manual + Computer Use paths |
| `reference/submission-form.md` | Submission form fields in detail |
| `reference/phase7-handoff.md` | Full Phase 7 protocol (AskUserQuestion text, form grouping) |
| `checklists/pre-publish.md` | Final check before pushing to GitHub |
| `checklists/submission-ready.md` | Final check before opening the submission form |

Don't load all of them. Load only what the current phase needs.
