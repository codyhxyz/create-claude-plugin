# PLUGIN_NAME — Claude Code plugin

This repo is a **Claude Code plugin**. The rules below apply to every session that opens anywhere in this tree. For the full end-to-end workflow (scaffold → build → test → host → submit), invoke the `create-claude-plugin` skill.

## Directory invariants

- All component directories (`skills/`, `agents/`, `hooks/`, `monitors/`, `bin/`) live at the **plugin root**.
- **Only** `plugin.json` and `marketplace.json` live inside `.claude-plugin/`. Never put components there — installation will silently fail.

## Path rules

- Every hook command, MCP `command`/`args`/`env`, monitor command, and script reference uses `${CLAUDE_PLUGIN_ROOT}/...`.
- Never use absolute paths. Never use `..` traversal. Plugins are copied to `~/.claude/plugins/cache/` on install and both will break.
- For state that must survive plugin updates, use `${CLAUDE_PLUGIN_DATA}` instead.

## Naming rules

- Plugin `name` is **kebab-case** (lowercase + digits + hyphens only).
- Don't use unowned brand names (`anthropic-*`, `official-*`, `claude-*-official`).
- Reserved names are rejected by the official marketplace: `claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `knowledge-work-plugins`, `life-sciences`.

## Manifest rules

- `version` lives in `plugin.json` only. Setting it in `marketplace.json` is silently ignored — `plugin.json` always wins.
- Bump `version` on every behavior change. Existing users won't see updates otherwise (plugins are cached).
- Keep `plugin.json` + `marketplace.json` in sync on `name`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`.

## Plugin-agent restriction

Agent files under `agents/*.md` **cannot** use `hooks`, `mcpServers`, or `permissionMode` frontmatter keys. These are blocked for security in plugin-owned agents. Configure hooks and MCP servers at the plugin level instead.

## Always-run commands

Before claiming the plugin works:

```bash
claude plugin validate .
```

Before claiming it's ready to submit to the official marketplace:

```bash
# From within the create-claude-plugin repo:
./scripts/check-submission.sh /path/to/this/plugin
```

For phase progress mid-development (doesn't exit on incomplete state):

```bash
./scripts/check-submission.sh /path/to/this/plugin --status
```

## Skill description rule (applies to every SKILL.md in `skills/`)

Frontmatter `description` describes **when to use**, not **what it does**. Start with "Use when...". The skill body is where the workflow lives. A description that summarizes the workflow will misfire on the model's routing logic.

## Pointer

Full walkthrough, reference docs, templates, and submission handoff live in the `create-claude-plugin` skill. Invoke it on phrases like "what's left on this plugin", "plugin status", "ready to submit", "add a skill", or "publish this".
