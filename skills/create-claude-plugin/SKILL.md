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

**When NOT to use:**
- Personal-only customization with no intent to share → use `~/.claude/` directly. Plugins add namespacing overhead (`/my-plugin:hello` instead of `/hello`); skip them for solo work.
- Editing an existing skill's content (no plugin shape changes) → just edit it.

## The seven phases

Run them in order. Each phase has a deliverable. Don't skip — phase N's output is phase N+1's input.

| # | Phase | Deliverable |
|---|---|---|
| 1 | **Decide** | Plugin or standalone? Which components? |
| 2 | **Scaffold** | Directory + `plugin.json` + `marketplace.json` + LICENSE + README stub |
| 3 | **Build** | Skills/agents/hooks/etc. wired in correct locations |
| 4 | **Test locally** | `claude --plugin-dir <path>` + `/reload-plugins` + `claude plugin validate .` all green |
| 5 | **Document** | README with install + usage + examples; CHANGELOG with v0.1.0 |
| 6 | **Host & make installable** | Push to GitHub; verify `/plugin marketplace add owner/repo` works |
| 7 | **Submit to official store** | Run `check-submission.sh`, paste output into the submission form |

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

Create the directory structure. **Critical mistake to avoid:** all component directories (`skills/`, `agents/`, `hooks/`, etc.) must live at the **plugin root**, not inside `.claude-plugin/`. Only `plugin.json` (and optionally `marketplace.json`) goes in `.claude-plugin/`.

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
- `templates/plugin/marketplace.json` → `.claude-plugin/marketplace.json` (mirrors plugin.json; lets users add the repo as a single-plugin marketplace)
- `templates/plugin/README.md` → `README.md` (replace placeholders)
- `templates/plugin/LICENSE` → `LICENSE` (MIT; update year + name)
- `templates/plugin/CHANGELOG.md` → `CHANGELOG.md`
- `templates/plugin/.gitignore` → `.gitignore`

**Naming rules:**
- Plugin `name` must be **kebab-case** (lowercase letters, digits, hyphens). Other forms work in Claude Code but the Claude.ai marketplace sync rejects them.
- Don't use brand names you don't own. Anthropic blocks names like `official-claude-plugins` or `anthropic-tools-v2`.
- Reserved names (cannot be used): `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `knowledge-work-plugins`, `life-sciences`.
- Skills are namespaced as `/<plugin-name>:<skill-name>` — pick a plugin name that reads well in that form.

For full schema details: `reference/plugin-manifest.md` and `reference/marketplace-manifest.md`.

---

## Phase 3: Build

Add components using the templates in `templates/` as starting points:

- **Skill:** `templates/skill/SKILL.md` → `skills/<your-skill-name>/SKILL.md`. Required frontmatter: `description` (when to use, third person, "Use when...", no workflow summary). Optional: `disable-model-invocation: true` if it should only fire on explicit slash command.
- **Agent:** `templates/agent/agent.md` → `agents/<your-agent-name>.md`. Frontmatter supports `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation`. **Not supported in plugin agents:** `hooks`, `mcpServers`, `permissionMode`.
- **Hook:** `templates/hook/hooks.json` → `hooks/hooks.json`. Use `${CLAUDE_PLUGIN_ROOT}` to reference scripts inside the plugin (paths get rewritten when installed to the cache).
- **MCP server:** Inline in `plugin.json` under `mcpServers`, or a `.mcp.json` at the plugin root. Same `${CLAUDE_PLUGIN_ROOT}` rule.
- **LSP server / Monitor:** See `reference/component-types.md`.

**Critical rules:**
- Use `${CLAUDE_PLUGIN_ROOT}` in *all* hook commands, MCP `command`/`args`/`env`, monitor `command`. Plugins are copied to a cache (`~/.claude/plugins/cache/`) when installed; absolute paths and `..` traversal **will not work**.
- For state that should survive plugin updates (node_modules, virtualenvs, caches), use `${CLAUDE_PLUGIN_DATA}` instead.
- Make hook scripts executable: `chmod +x scripts/your-script.sh`.

For each component type's full reference: `reference/component-types.md`.

---

## Phase 4: Test locally

Test before pushing. The `--plugin-dir` flag loads a plugin without installing it — local copy takes precedence over installed versions for that session.

```bash
claude --plugin-dir ./my-plugin
```

Inside the session:
- `/help` — your plugin's skills should appear under the `<plugin-name>:` namespace
- `/agents` — your agents should be listed
- Try invoking each skill: `/<plugin-name>:<skill-name>`
- After editing files: `/reload-plugins` (no restart needed)

Run validation (catches manifest errors, frontmatter problems, hook config issues):

```bash
claude plugin validate .
# or, inside Claude Code:
/plugin validate .
```

If anything fails: read the error, fix it, re-run. Common issues:
- Components inside `.claude-plugin/` instead of at the plugin root → move them up
- Hook script not executable → `chmod +x`
- Hook command uses absolute path → switch to `${CLAUDE_PLUGIN_ROOT}/...`
- Skill frontmatter missing `description` → add it

For full debugging recipes: `reference/component-types.md` § Troubleshooting.

---

## Phase 5: Document

The README is the primary install/usage doc. Use `templates/plugin/README.md` and fill in:

- **What it is** — one-sentence elevator pitch
- **What it does** — 2–4 bullets, concrete
- **Installation** — both `/plugin marketplace add` flow AND manual install
- **Usage** — at minimum one example invocation per skill/agent
- **Example interactions** — a real before/after; this is what convinces people the plugin is worth installing

Bump `version` in `plugin.json` (start at `0.1.0`). Add a CHANGELOG entry.

**For the submission form**, your README needs an "## Examples" or "## Example use cases" section — `check-submission.sh` looks for it.

---

## Phase 6: Host & make installable

Push to GitHub. Anyone can then install with:

```
/plugin marketplace add <owner>/<repo>
/plugin install <plugin-name>@<marketplace-name>
```

Where `<marketplace-name>` is the `name` field in your `.claude-plugin/marketplace.json` (which can be the same as your plugin name for a single-plugin repo).

```bash
gh repo create <owner>/<plugin-name> --public --source=. --remote=origin --push \
  --description "<plugin description>"
gh repo edit <owner>/<plugin-name> --add-topic claude-code --add-topic claude-skill
```

Other hosting options (GitLab, Bitbucket, npm, git URL, git-subdir) are documented in `reference/hosting-options.md`.

**Verify the install flow before submitting to the store:** in a fresh Claude Code session, run `/plugin marketplace add <owner>/<repo>` and `/plugin install`. If it doesn't work for you, it won't work for anyone.

---

## Phase 7: Submit to the official store (optional)

The official Anthropic marketplace is `claude-plugins-official`. Once accepted, your plugin is installable as `/plugin install <name>@claude-plugins-official` for everyone.

**Pre-flight (do before opening the form):**

```bash
./scripts/check-submission.sh /path/to/your/plugin
```

This script extracts every field the submission form requires from your `plugin.json` and `README.md`, verifies they're present, and prints them in a paste-ready format. If it errors, fix what's missing first.

The form has three pages:

**Page 1** — Account / submitter info (likely auto-filled from your Anthropic login).

**Page 2 — Plugin links + details:**
- Plugin link* — your repo URL
- Plugin homepage — optional docs URL (often your README)
- Plugin name* — kebab-case, not taken, no unowned brands
- Plugin description* — one concise sentence about what it does
- Example use cases* — formatted as `Example 1: ... \n Example 2: ...`

**Page 3 — Submission details:**
- Platforms* — surfaces you've tested on (multi-select)
- License type — `MIT`, `Apache-2.0`, etc. (matches your `LICENSE` file)
- Privacy policy URL — only if your plugin collects/transmits user data
- Submitter email* — your contact

Submit at one of:
- **https://claude.ai/settings/plugins/submit**
- **https://platform.claude.com/plugins/submit**

Anthropic reviews for quality + security. No public timeline. Once approved, you'll appear in `/plugin discover` and at https://claude.com/plugins.

For the form fields in detail (and what to do if your plugin name is taken): `reference/submission-form.md`.

---

## Quick reference

| Task | Command |
|---|---|
| Test locally | `claude --plugin-dir ./my-plugin` |
| Reload after edit | `/reload-plugins` (inside Claude Code) |
| Validate | `claude plugin validate .` |
| Install from a local marketplace | `/plugin marketplace add ./my-plugin` |
| Install from GitHub | `/plugin marketplace add owner/repo` |
| Check submission readiness | `./scripts/check-submission.sh ./my-plugin` |
| Submit to official store | https://claude.ai/settings/plugins/submit |

## Common mistakes

| Mistake | Fix |
|---|---|
| Components inside `.claude-plugin/` | Move them to the plugin root. Only `plugin.json`/`marketplace.json` live in `.claude-plugin/`. |
| Hook command uses absolute path or `..` | Use `${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh` |
| Plugin works locally but not after install | Plugins are copied to a cache. Files outside the plugin dir aren't copied. Use symlinks or restructure. |
| Skill description summarizes the workflow | Description should be **when to use**, not **what it does**. The skill body is for the workflow. |
| Plugin name in PascalCase or with spaces | Kebab-case only (lowercase + digits + hyphens). |
| Version bumped in `plugin.json` AND `marketplace.json` | Set in only one place — `plugin.json` always wins silently. |
| Bumped code without bumping version | Existing users won't see updates due to caching. Always bump the version when you change behavior. |
| Tried to use `hooks` / `mcpServers` / `permissionMode` in a plugin agent | Not supported in plugin agents (security restriction). |
| Reserved or impersonating name | See Phase 2 reserved-names list. Pick a different name. |

## Red flags — you're doing it wrong

- You're putting `commands/` or `skills/` inside `.claude-plugin/`
- Your plugin has zero components (only a manifest)
- You're hand-writing JSON without running `claude plugin validate`
- You're about to open the submission form without running `check-submission.sh`
- You're using brand names you don't own in your plugin name
- You haven't tested the actual install path (`/plugin marketplace add`) before submitting

## Reference index

| File | Load when |
|---|---|
| `reference/plugin-manifest.md` | Filling out `plugin.json` (full schema, every field) |
| `reference/marketplace-manifest.md` | Building `marketplace.json` (sources, channels, strict mode) |
| `reference/component-types.md` | Picking a component type or debugging one |
| `reference/hosting-options.md` | Hosting somewhere other than GitHub (GitLab, npm, git-subdir) |
| `reference/submission-form.md` | Pre-flight for the official marketplace submission |
| `checklists/pre-publish.md` | Final check before pushing to GitHub |
| `checklists/submission-ready.md` | Final check before opening the submission form |

Don't load all of them. Load only what the current phase needs.
