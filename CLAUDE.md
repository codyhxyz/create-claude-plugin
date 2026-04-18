# create-claude-plugin — Claude Code plugin

This repo is a **Claude Code plugin** that teaches other people how to build Claude Code plugins. It's meta: the skill at `skills/create-claude-plugin/SKILL.md` is the orchestrator for a 7-phase plugin-creation workflow, and `scripts/check-submission.sh` is the load-bearing pre-flight + phase-status tool.

Everything below applies to edits made anywhere in this tree.

## Canonical design docs — read first

- `ARCHITECTURE.md` — core principles, division of labor, anti-goals. **Read before adding a feature, reference doc, or template.**
- `skills/create-claude-plugin/SKILL.md` — the main skill; every rule you'd document here already lives there for end users.

## Directory invariants

- Component dirs (`skills/`, `hooks/`) live at the **plugin root**. Only `plugin.json` and `marketplace.json` live in `.claude-plugin/`.
- The one script that matters is `scripts/check-submission.sh`. Any new script must be pure shell, single-purpose, idempotent, and useful from outside this repo — see `ARCHITECTURE.md` § "Why `check-submission.sh` is the only script".

## Path rules

- Hook commands in `hooks/hooks.json` must use `${CLAUDE_PLUGIN_ROOT}/...`. Never absolute paths, never `..` traversal.
- Plugins are copied to `~/.claude/plugins/cache/` on install; absolute paths break silently.

## Defer, don't duplicate

- If a rule is enforceable by `claude plugin validate`, **defer to it** — don't re-document JSON schemas.
- If a rule is enforceable by `check-submission.sh`, **encode it there** — don't rely on the model remembering.
- The skill provides *judgment* (naming, scoping, component choice). The CLI + script provide *checks*.

## Always-run commands

Before claiming an edit works:

```bash
claude plugin validate .
```

For phase-grouped status on the meta-plugin itself:

```bash
./scripts/check-submission.sh . --status --offline
```

For a full submission pre-flight (online, with marketplace name availability):

```bash
./scripts/check-submission.sh . --no-open
```

## Version discipline

- Bump `version` in `.claude-plugin/plugin.json` on every behavior change — cached installs won't update otherwise.
- Add a `## [<version>]` entry at the top of `CHANGELOG.md` with today's date (`date +%Y-%m-%d`).
- Version lives in `plugin.json` only, never `marketplace.json`.

## Testing changes

- `claude --plugin-dir .` loads the plugin without installing it.
- `/reload-plugins` picks up edits without a restart.
- The SessionStart banner (`scripts/session-start-banner.sh`) fires on every Claude Code session started inside a plugin repo. Test by running it directly: `./scripts/session-start-banner.sh`.

## Don't

- Don't ship a generator framework or TUI. Templates are copy-and-fill.
- Don't re-implement what `claude plugin validate` does.
- Don't break the classic `check-submission.sh <dir>` invocation path — `--status` is additive.
