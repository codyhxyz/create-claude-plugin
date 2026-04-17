# Marketplace Manifest Reference (`marketplace.json`)

A marketplace is a catalog that lists one or more plugins. Hosted at `.claude-plugin/marketplace.json` in a git repo. Users add it with `/plugin marketplace add <source>`, then install individual plugins with `/plugin install <plugin>@<marketplace>`.

For a single-plugin repo, the marketplace and the plugin can both be hosted in the same repo: `marketplace.json` lists one plugin with `"source": "./"`.

## Minimal marketplace

```json
{
  "name": "my-plugins",
  "owner": { "name": "Your Name" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./plugins/my-plugin",
      "description": "What it does"
    }
  ]
}
```

> **Important:** the marketplace itself does **not** accept a top-level `description` field. Put marketplace descriptions under `metadata.description`. `description` is only valid on individual `plugins[]` entries. `claude plugin validate` errors with `root: Unrecognized key: "description"` if you put it at the top level.

## Single-plugin (repo == one plugin) shape

```json
{
  "name": "my-plugin",
  "metadata": {
    "description": "Single-plugin marketplace for my-plugin."
  },
  "owner": { "name": "Your Name", "email": "you@example.com" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./",
      "description": "What it does",
      "version": "0.1.0"
    }
  ]
}
```

## Required fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Marketplace identifier, kebab-case. Public — users see it: `/plugin install plugin@marketplace`. |
| `owner` | object | `{ name (req), email (opt) }` |
| `plugins` | array | List of plugin entries (each with `name` + `source` minimum) |

## Reserved marketplace names

You cannot use these (Anthropic-only):
- `claude-code-marketplace`
- `claude-code-plugins`
- `claude-plugins-official`
- `anthropic-marketplace`
- `anthropic-plugins`
- `agent-skills`
- `knowledge-work-plugins`
- `life-sciences`

Names that **impersonate** official ones (e.g., `official-claude-plugins`, `anthropic-tools-v2`) are also blocked.

## Optional metadata

| Field | Type | Description |
|---|---|---|
| `metadata.description` | string | Brief marketplace description (shown to users) |
| `metadata.version` | string | Marketplace version |
| `metadata.pluginRoot` | string | Base dir prepended to relative plugin sources. e.g. `"./plugins"` lets you write `"source": "formatter"` instead of `"source": "./plugins/formatter"`. |

## Plugin entries

Each entry can include any field from `plugin.json` (description, version, author, license, etc.) **plus** these marketplace-specific fields:

| Field | Type | Description |
|---|---|---|
| `name` | string | **Required.** kebab-case |
| `source` | string\|object | **Required.** Where to fetch the plugin |
| `category` | string | For organization in the marketplace UI |
| `tags` | array | For search |
| `strict` | boolean | Default `true`. See "Strict mode" below. |

## Plugin sources

Five source types determine how the plugin is fetched.

### 1. Relative path (same repo)

```json
{ "name": "my-plugin", "source": "./plugins/my-plugin" }
```

- Must start with `./`
- Resolved relative to the **marketplace root** (the dir containing `.claude-plugin/`), NOT relative to `marketplace.json` itself
- Works only when users add the marketplace via Git. URL-based marketplace adds (`/plugin marketplace add https://example.com/marketplace.json`) won't resolve relative paths — use external sources instead

### 2. GitHub

```json
{
  "name": "github-plugin",
  "source": {
    "source": "github",
    "repo": "owner/plugin-repo",
    "ref": "v2.0.0",
    "sha": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
  }
}
```

| Field | Required | Description |
|---|---|---|
| `repo` | yes | `owner/repo` format |
| `ref` | no | Branch or tag (defaults to default branch) |
| `sha` | no | Full 40-char commit SHA for exact pinning |

### 3. Generic git URL

```json
{
  "name": "git-plugin",
  "source": {
    "source": "url",
    "url": "https://gitlab.com/team/plugin.git",
    "ref": "main"
  }
}
```

- `url` is the full git URL (`.git` suffix optional, supports Azure DevOps + AWS CodeCommit)
- Same `ref` and `sha` semantics as GitHub source

### 4. Git subdirectory (monorepo)

```json
{
  "name": "my-plugin",
  "source": {
    "source": "git-subdir",
    "url": "https://github.com/acme-corp/monorepo.git",
    "path": "tools/claude-plugin",
    "ref": "v2.0.0"
  }
}
```

- Uses sparse, partial clone — only the subdirectory is fetched
- `url` accepts GitHub `owner/repo` shorthand or SSH URL too

### 5. npm package

```json
{
  "name": "my-npm-plugin",
  "source": {
    "source": "npm",
    "package": "@acme/claude-plugin",
    "version": "^2.0.0",
    "registry": "https://npm.example.com"
  }
}
```

| Field | Required | Description |
|---|---|---|
| `package` | yes | Package name or scoped (`@org/pkg`) |
| `version` | no | semver range |
| `registry` | no | Custom registry URL |

## Strict mode

Controls whether `plugin.json` is the authority for component definitions.

| Value | Behavior |
|---|---|
| `true` (default) | `plugin.json` is the authority. Marketplace entry can supplement; both merge. |
| `false` | Marketplace entry is the entire definition. If the plugin also has its own `plugin.json` with components, that's a **conflict and the plugin fails to load**. |

Use `strict: false` when the marketplace operator wants full control — e.g., curating a plugin's components differently than the author intended.

## Plugin source vs marketplace source

These are different and easy to confuse:

| Concept | Set by | What it controls |
|---|---|---|
| **Marketplace source** | `/plugin marketplace add` or `extraKnownMarketplaces` | Where to fetch `marketplace.json`. Supports `ref`, NOT `sha`. |
| **Plugin source** | `source` field of each plugin entry inside `marketplace.json` | Where to fetch each plugin. Supports `ref` AND `sha`. |

A marketplace at `acme/catalog` can list a plugin fetched from `acme/code-formatter`. The two repos are pinned independently.

## Validation

```bash
claude plugin validate .
# or, inside Claude Code:
/plugin validate .
```

Common errors:
- `Duplicate plugin name "x" found in marketplace` — give each plugin a unique `name`
- `plugins[0].source: Path contains ".."` — use paths relative to marketplace root, no `..`
- `Plugin name "x" is not kebab-case` — uppercase/spaces/special chars; rename
- `Marketplace has no plugins defined` — add at least one plugin entry

## Version resolution

Set `version` in **either** `plugin.json` or the marketplace entry, not both. If both, `plugin.json` silently wins.

- For relative-path plugins (single-repo marketplace): set in marketplace entry
- For all other sources: set in `plugin.json`

## Release channels

Stable + latest channels are done by hosting two marketplaces that point to different refs of the same plugin:

```json
{
  "name": "stable-tools",
  "plugins": [
    {
      "name": "code-formatter",
      "source": { "source": "github", "repo": "acme/code-formatter", "ref": "stable" }
    }
  ]
}
```

```json
{
  "name": "latest-tools",
  "plugins": [
    {
      "name": "code-formatter",
      "source": { "source": "github", "repo": "acme/code-formatter", "ref": "latest" }
    }
  ]
}
```

The plugin's `plugin.json` must declare a **different `version`** at each ref. Same version → Claude Code treats them as identical and skips the update.
