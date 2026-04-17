# Component Types Reference

A plugin can include any combination of these. Each goes in its conventional location at the **plugin root** (not inside `.claude-plugin/`).

| Component | Default location | Format | Best for |
|---|---|---|---|
| Skills | `skills/<name>/SKILL.md` | Markdown + YAML frontmatter | Model-invoked instructions; Claude reads when description matches |
| Commands (legacy) | `commands/*.md` | Flat markdown files | Same as skills, older format. Prefer `skills/` for new plugins. |
| Agents | `agents/*.md` | Markdown + YAML frontmatter | Specialized subagents the main agent delegates to |
| Hooks | `hooks/hooks.json` | JSON | Event handlers (PostToolUse, SessionStart, etc.) |
| MCP servers | `.mcp.json` (or inline) | JSON | External tool servers (databases, APIs, custom tools) |
| LSP servers | `.lsp.json` (or inline) | JSON | Language servers for real-time code intelligence |
| Monitors | `monitors/monitors.json` | JSON | Background processes streaming notifications into the session |
| Output styles | `output-styles/*.md` | Markdown | Custom output formats (e.g., terse mode) |
| Executables | `bin/*` | Any executable | Binaries added to Bash tool's `PATH` |
| Default settings | `settings.json` (root) | JSON | Activate a plugin agent as main thread, set status line |

## Skills

```
skills/
├── code-reviewer/
│   ├── SKILL.md
│   ├── reference.md       (optional supporting file)
│   └── scripts/           (optional)
└── pdf-processor/
    └── SKILL.md
```

`SKILL.md` frontmatter:

```yaml
---
description: Review code for bugs, security, and performance. Use when reviewing code, checking PRs, or analyzing code quality.
disable-model-invocation: true   # optional — only fires on explicit /skill-name
---
```

**Description guidance:** describe **when to use**, not **what it does**. "Use when..." prefix is conventional. If the description summarizes the workflow, Claude follows the description and skips the body.

Skills support `$ARGUMENTS` in the body — captures any text after the slash invocation: `/my-plugin:hello Alex` → `$ARGUMENTS` = `Alex`.

## Agents

```markdown
---
name: agent-name
description: What this agent specializes in and when Claude should invoke it
model: sonnet
effort: medium
maxTurns: 20
disallowedTools: Write, Edit
---

Detailed system prompt for the agent describing its role, expertise, and behavior.
```

Supported frontmatter fields: `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation` (only valid value: `"worktree"`).

**Not supported in plugin agents (security):** `hooks`, `mcpServers`, `permissionMode`.

## Hooks

`hooks/hooks.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format-code.sh"
          }
        ]
      }
    ]
  }
}
```

**All hook events** (case-sensitive):

| Event | Fires when |
|---|---|
| `SessionStart` | Session begins/resumes |
| `UserPromptSubmit` | User submits a prompt, before Claude processes it |
| `PreToolUse` | Before a tool call. Can block. |
| `PermissionRequest` | Permission dialog appears |
| `PermissionDenied` | Tool denied. Return `{retry: true}` to allow retry. |
| `PostToolUse` | After tool succeeds |
| `PostToolUseFailure` | After tool fails |
| `Notification` | Claude Code sends a notification |
| `SubagentStart` / `SubagentStop` | Subagent lifecycle |
| `TaskCreated` / `TaskCompleted` | Task lifecycle |
| `Stop` | Claude finishes responding |
| `StopFailure` | Turn ends due to API error (output/exit ignored) |
| `TeammateIdle` | Agent-team teammate about to idle |
| `InstructionsLoaded` | CLAUDE.md or `.claude/rules/*.md` loaded |
| `ConfigChange` | Config file changes during session |
| `CwdChanged` | Working dir changes (e.g., after `cd`) |
| `FileChanged` | Watched file changes (use `matcher` for filename pattern) |
| `WorktreeCreate` / `WorktreeRemove` | Worktree lifecycle |
| `PreCompact` / `PostCompact` | Context compaction |
| `Elicitation` / `ElicitationResult` | MCP server requests user input |
| `SessionEnd` | Session terminates |

**Hook types:**

- `command` — execute shell commands or scripts
- `http` — POST event JSON to a URL
- `prompt` — evaluate a prompt with an LLM (uses `$ARGUMENTS` for context)
- `agent` — run an agentic verifier with tools

**Critical:** scripts must be executable (`chmod +x`) and use `${CLAUDE_PLUGIN_ROOT}` for paths.

## MCP servers

```json
{
  "mcpServers": {
    "plugin-database": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": {
        "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data"
      }
    },
    "plugin-api-client": {
      "command": "npx",
      "args": ["@company/mcp-server", "--plugin-mode"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

Plugin MCP servers start automatically when the plugin is enabled. Tools appear in Claude's toolkit alongside built-ins.

## LSP servers

`.lsp.json`:

```json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": { ".go": "go" }
  }
}
```

Required fields: `command` (must be in PATH), `extensionToLanguage`.

Optional fields: `args`, `transport` (`stdio` default or `socket`), `env`, `initializationOptions`, `settings`, `workspaceFolder`, `startupTimeout`, `shutdownTimeout`, `restartOnCrash`, `maxRestarts`.

**Users must install the language server binary themselves.** The plugin only configures the connection.

For common languages (TypeScript, Python, Rust), use the official LSP plugins from `claude-plugins-official` instead of writing your own.

## Monitors

`monitors/monitors.json`:

```json
[
  {
    "name": "deploy-status",
    "command": "${CLAUDE_PLUGIN_ROOT}/scripts/poll-deploy.sh ${user_config.api_endpoint}",
    "description": "Deployment status changes"
  },
  {
    "name": "error-log",
    "command": "tail -F ./logs/error.log",
    "description": "Application error log",
    "when": "on-skill-invoke:debug"
  }
]
```

Required: `name`, `command`, `description`.

`when`:
- `"always"` (default) — start at session start + on plugin reload
- `"on-skill-invoke:<skill-name>"` — start when the named skill is first invoked

Each stdout line from `command` is delivered to Claude as a notification. Requires Claude Code v2.1.105+. Run only in interactive CLI sessions, unsandboxed at the same trust level as hooks.

## Settings

`settings.json` at plugin root. Only honored keys:

```json
{
  "agent": "security-reviewer",
  "subagentStatusLine": "..."
}
```

`agent` activates one of the plugin's custom agents as the main thread.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Plugin not loading | Invalid `plugin.json` | `claude plugin validate` and read errors |
| Skills not appearing | `skills/` inside `.claude-plugin/` | Move to plugin root |
| Hook not firing | Script not executable | `chmod +x scripts/foo.sh` |
| Hook event ignored | Event name typo | Case-sensitive: `PostToolUse`, not `postToolUse` |
| MCP server fails | Absolute path used | Switch to `${CLAUDE_PLUGIN_ROOT}/...` |
| File not found after install | Path traverses outside plugin dir (`../foo`) | Plugins copied to cache; restructure or symlink |
| LSP `Executable not found in $PATH` | Language server not installed | Install separately (e.g., `npm install -g typescript-language-server`) |

Run `claude --debug` to see plugin load details, errors, and component registration.
