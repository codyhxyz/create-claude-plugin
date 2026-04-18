---
name: create-claude-plugin
description: Use when the user wants to create, package, or publish a Claude Code plugin — including converting a personal `.claude/` config into a shareable plugin, adding a marketplace, hosting on GitHub, or submitting to the official Anthropic plugin marketplace. Triggers on phrases like "make a Claude plugin", "package this skill", "publish to the Claude store", "claude-plugin-official", "/plugin marketplace add", or any request to scaffold, distribute, or submit a Claude Code plugin end-to-end.
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

**When NOT to use:**
- Personal-only customization with no intent to share → use `~/.claude/` directly. Plugins add namespacing overhead (`/my-plugin:hello` instead of `/hello`); skip them for solo work.
- Editing an existing skill's content (no plugin shape changes) → just edit it.

## The seven phases

Run them in order. Each phase has a deliverable. Don't skip — phase N's output is phase N+1's input.

| # | Phase | Deliverable |
|---|---|---|
| 0 | **Existing plugin?** | If so, skip scaffolding — branch into the update flow |
| 1 | **Decide** | Plugin or standalone? Which components? |
| 2 | **Scaffold** | Directory + `plugin.json` + `marketplace.json` + LICENSE + README stub |
| 3 | **Build** | Skills/agents/hooks/etc. wired in correct locations |
| 4 | **Test locally** | `claude --plugin-dir <path>` + `/reload-plugins` + `claude plugin validate .` all green |
| 5 | **Document** | README with install + usage + examples; CHANGELOG with v0.1.0 |
| 6 | **Host & make installable** | Push to GitHub; verify `/plugin marketplace add owner/repo` works |
| 7 | **Submit to official store** | Run `check-submission.sh`, fill the form |

---

## Phase 0: Is this an existing plugin?

If the user already has a `.claude-plugin/plugin.json` in the target directory, **skip Phases 1–3** and run the update flow instead:

1. **Bump `version`** in `.claude-plugin/plugin.json` per semver (patch = fix, minor = new feature, major = breaking). Set in only one place — `plugin.json` always wins over `marketplace.json` silently.
2. **Add a CHANGELOG entry** at the top of `CHANGELOG.md`: new version heading, today's date (`date +%Y-%m-%d`), summary of changes. Keep the prior entries; don't rewrite history.
3. **Re-run validation + pre-flight:**
   ```bash
   claude plugin validate <plugin-path>
   ${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"
   ```
4. **Push the update.** Commit, tag the new version (`git tag v<x.y.z> && git push --tags`), and push. Users running `/plugin install` will pick up the new version on refresh.
5. **If the plugin is already in `claude-plugins-official`, re-submit.** Anthropic reviews updates separately — the official marketplace doesn't auto-pull new tags. Re-run Phase 7 with the new version.

Updates skip scaffolding + component decisions but still go through Phases 4 (test), 5 (doc), 6 (host), and 7 (submit, if applicable).

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

Cowork has no CLI. Two paths, both covered in detail in `reference/cowork-testing.md`:

- **Path A — manual:** Claude desktop → Cowork tab → Customize → Browse plugins → install or `.zip` upload → smoke-test.
- **Path B — semi-automated:** Claude Code's `computer-use` MCP drives the desktop app (macOS + Pro/Max only).

**Don't claim Cowork support on the submission form unless you've actually tested it.** `check-submission.sh` blocks the Cowork checkbox unless `COWORK_TESTED=yes` is set in the environment.

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

---

## Phase 6: Host & make installable

Push to GitHub using the helper script (idempotent — safe to re-run on updates):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/publish-to-github.sh "<plugin-path>"
```

The script reads `.claude-plugin/plugin.json` for name, description, and homepage; auto-detects topics from the component layout (`claude-skill` if `skills/` exists, etc.) + manifest `keywords`; creates the repo if it doesn't exist; and always runs `gh repo edit` to sync metadata.

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
| Pre-flight the submission (model invokes via Bash) | `${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"` |
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
| `reference/cowork-testing.md` | Phase 4b — manual + Computer Use paths |
| `reference/submission-form.md` | Submission form fields in detail |
| `reference/phase7-handoff.md` | Full Phase 7 protocol (AskUserQuestion text, form grouping) |
| `checklists/pre-publish.md` | Final check before pushing to GitHub |
| `checklists/submission-ready.md` | Final check before opening the submission form |

Don't load all of them. Load only what the current phase needs.
