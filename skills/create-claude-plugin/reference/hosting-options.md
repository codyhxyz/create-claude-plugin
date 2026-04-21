# Hosting Options Reference

Where to host your plugin and how users install it.

## Option 1: GitHub (recommended)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/publish-to-github.sh <plugin-dir>
```

Idempotent — safe to re-run. Reads `.claude-plugin/plugin.json` for name/description/homepage/version, auto-detects topics from the component layout + manifest keywords, creates the repo (or pushes the current branch), tags the release, and opens a PR against the meta-marketplace. See **Phase 6** in `SKILL.md` for the full list of env-var overrides.

Users install:

```
/plugin marketplace add owner/plugin-name && /plugin install plugin-name@<marketplace-name>
```

`<marketplace-name>` = the `name` field in your `.claude-plugin/marketplace.json`.

Pin to a branch or tag with `@ref`:

```bash
claude plugin marketplace add owner/plugin-name@v1.0
```

## Option 2: Other git hosts (GitLab, Bitbucket, self-hosted)

```bash
/plugin marketplace add https://gitlab.com/team/plugin.git
```

## Option 3: Direct URL to marketplace.json

```bash
/plugin marketplace add https://example.com/marketplace.json
```

**Warning:** URL-based marketplaces only download `marketplace.json` itself. Plugins with `"source": "./plugins/foo"` (relative paths) **will fail** — files aren't fetched from the server. Use GitHub, npm, or git URL sources for the plugin entries instead.

## Option 4: npm

Publish your plugin as an npm package, then list it:

```json
{
  "source": {
    "source": "npm",
    "package": "@you/your-plugin",
    "version": "^1.0.0",
    "registry": "https://npm.example.com"
  }
}
```

## Option 5: Local path (development / testing only)

```bash
/plugin marketplace add ./my-marketplace
```

Or load a single plugin without installing:

```bash
claude --plugin-dir ./my-plugin
# multiple at once:
claude --plugin-dir ./plugin-one --plugin-dir ./plugin-two
```

## Private repositories

**Manual install + update** uses your existing git credential helpers (HTTPS via `gh auth login`, macOS Keychain, `git-credential-store`; SSH via `ssh-agent` with the host in `known_hosts`). No setup needed.

**Background auto-update** runs at startup without credential helpers (interactive prompts would block startup). Requires an environment token:

| Provider | Env var | Notes |
|---|---|---|
| GitHub | `GITHUB_TOKEN` or `GH_TOKEN` | PAT with `repo` scope, or GitHub App token |
| GitLab | `GITLAB_TOKEN` or `GL_TOKEN` | PAT with `read_repository` scope |
| Bitbucket | `BITBUCKET_TOKEN` | App password or repo access token |

```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

## Team distribution

Pre-register your marketplace via `.claude/settings.json` so teammates are auto-prompted:

```json
{
  "extraKnownMarketplaces": {
    "company-tools": {
      "source": { "source": "github", "repo": "your-org/claude-plugins" }
    }
  },
  "enabledPlugins": {
    "code-formatter@company-tools": true
  }
}
```

## Container / CI pre-population

Set `CLAUDE_CODE_PLUGIN_SEED_DIR` to a pre-populated `~/.claude/plugins` snapshot. Plugins start available without runtime cloning.

Build the seed:

```bash
CLAUDE_CODE_PLUGIN_CACHE_DIR=/opt/claude-seed claude plugin marketplace add your-org/plugins
CLAUDE_CODE_PLUGIN_CACHE_DIR=/opt/claude-seed claude plugin install my-tool@your-plugins
```

Then in your container runtime: `CLAUDE_CODE_PLUGIN_SEED_DIR=/opt/claude-seed`.

Seed directory is read-only. Auto-updates disabled. Seed entries override user config on each startup.

## Marketplace CLI commands

```bash
claude plugin marketplace add <source> [--scope user|project|local] [--sparse paths...]
claude plugin marketplace list [--json]
claude plugin marketplace remove <name>     # uninstalls all plugins from it
claude plugin marketplace update [name]     # refresh; updates all if no name
```

## Plugin CLI commands

```bash
claude plugin install <plugin>@<marketplace> [--scope ...]
claude plugin uninstall <plugin>@<marketplace> [--keep-data]
claude plugin enable <plugin>@<marketplace>
claude plugin disable <plugin>@<marketplace>
claude plugin update <plugin>@<marketplace>
claude plugin list [--json] [--available]
claude plugin validate <path>
```

## Scopes

Where the plugin's `enabledPlugins` entry is written:

| Scope | File | Use |
|---|---|---|
| `user` (default) | `~/.claude/settings.json` | Personal, available across all projects |
| `project` | `.claude/settings.json` | Team-shared via version control |
| `local` | `.claude/settings.local.json` | Project-specific, gitignored |
| `managed` | Managed settings | Org-managed; read-only, update-only |

## Troubleshooting

| Issue | Fix |
|---|---|
| Marketplace not loading | `claude plugin validate .`; check JSON syntax + access permissions |
| Plugin install fails | Verify source URL is accessible; for GitHub, repo is public or you have access |
| Private repo auth fails (manual) | `gh auth status`; try cloning manually |
| Private repo auth fails (auto-update) | Set `$GITHUB_TOKEN`; check `repo` scope; verify not expired |
| Updates fail offline | `export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` retains stale cache instead of wiping |
| Git operations time out | `export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000` (5 min) |
| Files outside plugin dir not found | Plugins copy to cache; can't reference `..` paths. Use symlinks or restructure. |
