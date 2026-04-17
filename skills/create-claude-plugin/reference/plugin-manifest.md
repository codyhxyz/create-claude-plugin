# Plugin Manifest Reference (`plugin.json`)

Full schema for `.claude-plugin/plugin.json`. The manifest is **optional** — if omitted, Claude Code auto-discovers components in default locations and uses the directory name as the plugin name. Include a manifest when you need metadata or custom component paths.

## Complete schema

```json
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": "./custom/agents/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "monitors": "./monitors.json",
  "userConfig": { "...": "..." },
  "channels": [ { "...": "..." } ],
  "dependencies": [
    "helper-lib",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

## Required fields

If you include a manifest at all, **`name` is the only required field.**

| Field | Type | Description |
|---|---|---|
| `name` | string | Unique identifier (kebab-case, no spaces). Used for namespacing components: a skill `hello` in plugin `my-plugin` becomes `/my-plugin:hello`. |

## Metadata fields

| Field | Type | Description |
|---|---|---|
| `version` | string | Semantic version. If also set in marketplace entry, `plugin.json` wins silently. Set in only one place. |
| `description` | string | Brief explanation of plugin purpose. Shown in the plugin manager. |
| `author` | object | `{ name, email?, url? }` |
| `homepage` | string | Documentation URL |
| `repository` | string | Source code URL |
| `license` | string | SPDX identifier (`MIT`, `Apache-2.0`, etc.) |
| `keywords` | array | Discovery tags |

## Component path fields

By default, components are auto-discovered from the standard directories. Override these fields only when you need a custom layout.

| Field | Type | Default location | Notes |
|---|---|---|---|
| `skills` | string\|array | `skills/` | A custom path **replaces** the default. To keep the default + add more: `["./skills/", "./extras/"]` |
| `commands` | string\|array | `commands/` | Flat `.md` files (legacy). Use `skills/` for new plugins. |
| `agents` | string\|array | `agents/` | Custom path replaces default |
| `hooks` | string\|array\|object | `hooks/hooks.json` | Different merge semantics — multiple sources combine |
| `mcpServers` | string\|array\|object | `.mcp.json` | Different merge semantics — multiple sources combine |
| `lspServers` | string\|array\|object | `.lsp.json` | Different merge semantics — multiple sources combine |
| `outputStyles` | string\|array | `output-styles/` | Custom path replaces default |
| `monitors` | string\|array | `monitors/monitors.json` | Custom path replaces default |
| `dependencies` | array | none | Other plugins this requires; supports semver constraints |

**Path rules:**
- All paths must be **relative** to the plugin root and start with `./`
- No `..` traversal — plugins are copied to a cache when installed and external files won't be present
- Components from custom paths use the same naming/namespacing rules as defaults

## userConfig

Declare values Claude Code prompts the user for when the plugin is enabled. Avoids forcing users to hand-edit `settings.json`.

```json
{
  "userConfig": {
    "api_endpoint": {
      "description": "Your team's API endpoint",
      "sensitive": false
    },
    "api_token": {
      "description": "API authentication token",
      "sensitive": true
    }
  }
}
```

- Keys must be valid identifiers
- Available as `${user_config.KEY}` in MCP/LSP configs, hook commands, monitor commands, and (non-sensitive only) skill/agent content
- Also exported as `CLAUDE_PLUGIN_OPTION_<KEY>` env vars to subprocesses
- Non-sensitive values stored in `settings.json`; sensitive values go to system keychain (~2 KB total limit shared with OAuth tokens)

## Environment variables (substitution)

Two variables are substituted inline in skill/agent content, hook commands, monitor commands, and MCP/LSP configs. They're also exported to subprocesses.

| Variable | Resolves to | When to use |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the plugin's installation directory | Reference scripts, binaries, and config files **bundled with the plugin**. Changes when the plugin updates — files written here don't survive updates. |
| `${CLAUDE_PLUGIN_DATA}` | `~/.claude/plugins/data/{id}/` | Persistent state: installed dependencies (`node_modules`, virtualenvs), generated code, caches. Survives plugin updates. Auto-created on first reference. |

**Common pattern: install dependencies once on update**

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "diff -q \"${CLAUDE_PLUGIN_ROOT}/package.json\" \"${CLAUDE_PLUGIN_DATA}/package.json\" >/dev/null 2>&1 || (cd \"${CLAUDE_PLUGIN_DATA}\" && cp \"${CLAUDE_PLUGIN_ROOT}/package.json\" . && npm install) || rm -f \"${CLAUDE_PLUGIN_DATA}/package.json\""
      }]
    }]
  }
}
```

The `diff` exits nonzero on first run or when the bundled manifest changes, triggering reinstall. The trailing `rm` cleans up if `npm install` fails so the next session retries.

## Validation rules summary

| Rule | What happens if violated |
|---|---|
| `name` is kebab-case | Claude Code accepts other forms; Claude.ai marketplace sync rejects |
| Component dirs at plugin root, not in `.claude-plugin/` | Components silently invisible |
| Hook scripts executable | Hook silently doesn't fire |
| All paths relative + start with `./` | Validation error |
| No `..` in paths | Validation error |
| Bumped behavior, didn't bump version | Existing users don't see update (cache) |
| Same version at two refs | Update detection skips it |

Run `claude plugin validate .` to check syntactically.

## Settings file (`settings.json` at plugin root)

Optional. Only two keys are currently honored:

- `agent` — name of one of the plugin's agents to activate as the main thread (applies its system prompt, tools, model)
- `subagentStatusLine` — see `/en/statusline#subagent-status-lines`

Settings from `settings.json` take priority over `settings` declared in `plugin.json`. Unknown keys silently ignored.
