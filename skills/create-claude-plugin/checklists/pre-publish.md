# Pre-publish checklist

Run before pushing to GitHub.

## Structure

- [ ] `.claude-plugin/plugin.json` exists
- [ ] `.claude-plugin/marketplace.json` exists (for single-plugin repos)
- [ ] All component dirs (`skills/`, `agents/`, `hooks/`, etc.) are at the **plugin root**, NOT inside `.claude-plugin/`
- [ ] `LICENSE` exists
- [ ] `README.md` exists with install + usage + at least one example
- [ ] `CHANGELOG.md` exists with a v0.1.0 entry
- [ ] `.gitignore` exists

## Manifest

- [ ] `name` is kebab-case
- [ ] `name` is not in the reserved list (claude-code-marketplace, claude-plugins-official, etc.)
- [ ] `name` doesn't impersonate Anthropic brands
- [ ] `description` is one concise sentence
- [ ] `version` is `0.1.0` (or higher) and follows semver
- [ ] `author.name`, `author.email` set
- [ ] `homepage` and `repository` URLs point to your actual repo
- [ ] `license` SPDX identifier matches your `LICENSE` file
- [ ] `keywords` include `claude-code` + relevant tags
- [ ] Version is set in **only one** of `plugin.json` or `marketplace.json` (plugin.json wins silently)

## Components

- [ ] Each skill has frontmatter `description` starting with "Use when..."
- [ ] No skill description summarizes the workflow (it's about *when*, not *what*)
- [ ] Hook scripts are executable (`chmod +x`)
- [ ] All hook commands use `${CLAUDE_PLUGIN_ROOT}/...` (no absolute paths, no `..` traversal)
- [ ] All MCP `command`/`args`/`env` paths use `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_PLUGIN_DATA}`
- [ ] No plugin agent uses `hooks`, `mcpServers`, or `permissionMode` (not supported)

## Validation

- [ ] `claude plugin validate .` passes with no errors
- [ ] No warnings about kebab-case naming
- [ ] No warnings about missing description / no plugins defined

## Local test

- [ ] `claude --plugin-dir ./` loads the plugin without errors
- [ ] `/help` shows your skills under the `<plugin-name>:` namespace
- [ ] Each skill responds when invoked
- [ ] Each agent appears in `/agents`
- [ ] Hooks fire on the matching events
- [ ] `/reload-plugins` picks up edits without restart

## Repo hygiene

- [ ] Initial commit message is clear (not "wip" or "init")
- [ ] No secrets / `.env` files / personal config committed
- [ ] No `node_modules/` or build artifacts
- [ ] README's `/plugin marketplace add owner/repo` line uses your actual `owner/repo`
