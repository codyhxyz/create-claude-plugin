# create-claude-plugin — Claude Code plugin

This repo is a **Claude Code plugin** that teaches other people how to build Claude Code plugins. It's meta: the skill at `skills/create-claude-plugin/SKILL.md` is the orchestrator for a 7-phase plugin-creation workflow, and `scripts/check-submission.sh` is the load-bearing pre-flight + phase-status tool.

Everything below applies to edits made anywhere in this tree.

## Canonical design docs — read first

- `ARCHITECTURE.md` — core principles, division of labor, anti-goals. **Read before adding a feature, reference doc, or template.**
- `skills/create-claude-plugin/SKILL.md` — the main skill; every rule you'd document here already lives there for end users.

## Directory invariants

- Component dirs (`skills/`, `hooks/`) live at the **plugin root**. Only `plugin.json` and `marketplace.json` live in `.claude-plugin/`.
- The one script that matters is `scripts/check-submission.sh`. Any new script must be pure shell, single-purpose, idempotent, and useful from outside this repo — see `ARCHITECTURE.md` § "Why `check-submission.sh` is the only script".

## Two-layer validation architecture

- **Layer 1 (generic repo health):** `scripts/readiness.sh` + `scripts/readiness-fix.sh`. Ported from `github.com/parcadei/ContinuousClaudeV4.7` (MIT) with Category 7 (tldr) removed. Scores 20 criteria / 6 categories: lint, formatter, types, pre-commit, tests, coverage, docs, security, task discovery. Advisory only — **never blocks**. Wired as Phase 4.5 in the skill.
- **Layer 2 (marketplace-specific):** `scripts/check-submission.sh`. 17 submission-form rules (manifest, naming, marketplace.json, Cowork portability, marketing artifacts). Blocking in classic mode.
- The two are orthogonal by design: readiness doesn't know about plugins, check-submission doesn't know about linters. Don't merge them. `check-submission.sh` shells out to `readiness.sh` once to emit the score as informational output, and that's the only coupling.

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

- Bump `version` in `.claude-plugin/plugin.json` **when you ship**, not on every edit. A version is only a version if something shipped — accumulated behavior changes between ships share one bump at release time. (Cached installs won't pick up changes without a bump, so make sure the ship includes one.)
- On ship, add a `## [<version>]` entry at the top of `CHANGELOG.md` with today's date (`date +%Y-%m-%d`) covering everything that landed since the last release.
- Version lives in `plugin.json` only, never `marketplace.json`.

## Testing changes

- `claude --plugin-dir .` loads the plugin without installing it.
- `/reload-plugins` picks up edits without a restart.
- The SessionStart banner (`scripts/session-start-banner.sh`) fires on every Claude Code session started inside a plugin repo. Test by running it directly: `./scripts/session-start-banner.sh`.

## Don't

- Don't ship a generator framework or TUI. Templates are copy-and-fill.
- Don't re-implement what `claude plugin validate` does.
- Don't break the classic `check-submission.sh <dir>` invocation path — `--status` is additive.
