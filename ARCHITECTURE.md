# Architecture

Canonical design doc for `create-claude-plugin`. Read this before adding features, reference docs, or new templates.

---

## Core principle — lean on scripts and the CLI, not on model recall

Claude Code already ships `claude plugin validate` — a deterministic checker for manifest syntax, frontmatter, and hook config. The skill should never re-implement what the CLI already does.

What the CLI **doesn't** check (and so the skill must):

- Whether the plugin name is **available** in the official marketplace
- Whether the README has an Examples section formatted for the submission form
- Whether every field the submission form asks for is actually filled in
- Whether the plugin works as advertised (no validator can know this — but the skill can prompt the user to test)

Two corollaries:

1. **If a rule is enforceable by `claude plugin validate`, defer to it.** Don't re-document JSON schemas the CLI already validates — link to the official docs.
2. **If a rule is enforceable by `check-submission.sh`, encode it there.** The script returns nonzero on missing fields. The model doesn't have to remember.

---

## Division of labor

| Concern | Lives in | Why |
|---|---|---|
| JSON schema validation | `claude plugin validate` (CLI, external) | Deterministic; already exists |
| Field presence (name, description, repo URL, examples in README) | `scripts/check-submission.sh` | Boolean checks belong in code |
| Name availability against `claude-plugins-official` | `scripts/check-submission.sh` (online check) | Network call; the model can't predict |
| Reserved-name / brand-impersonation check | `scripts/check-submission.sh` | Static list; deterministic |
| Picking *which* components to use | Skill | Judgment; depends on user goal |
| Writing a good description / examples | Skill | Synthesis; this is what the model is for |
| Translating CLI errors → "here's what to fix" | Skill | Recipe per error class |
| Walking the user through phases | Skill | Conversational orchestration |

---

## Why a single skill, not multiple

Considered architectures:

1. **One mega-skill with phases** ← **chosen**
2. Multiple skills (`scaffold`, `validate`, `submit`) chained
3. A subagent that does the whole thing

Picked **#1** because:

- The user's mental model is one task ("make a plugin"), not three
- Phases share state (the plugin dir, naming decisions, etc.) — splitting them forces the user to re-establish context per skill
- The skill can be loaded once and the user can navigate phases as a conversation; sub-skills would need re-invocation
- Reference files (`reference/*.md`) handle the "load only what you need" concern without splitting the orchestration

If the skill ever grows past ~700 lines or starts conflating distinct judgment domains, split it.

---

## Reference files: progressive disclosure

The main `SKILL.md` is the orchestrator. It's intentionally scannable (~500 lines) and points to `reference/*.md` files for depth. Each reference file is loaded only when the relevant phase needs it.

This matches the pattern from Anthropic's own writing-skills skill: "load only what you need." The main file is the always-loaded surface; the references are the progressive disclosure.

If a reference file grows past ~300 lines, consider splitting it by sub-topic (e.g., `component-types-skills.md`, `component-types-hooks.md`). Right now they're all comfortably under that.

---

## Templates: copy-and-fill, not generate-and-pray

Templates use ALL_CAPS placeholders (`PLUGIN_NAME`, `YOUR_NAME`, `YOUR_EMAIL`). The skill instructs the user (or itself) to copy + replace.

**Why placeholders, not a generator script?** A generator would need to:
- Prompt for every value
- Handle name validation (already done by `check-submission.sh`)
- Decide which templates to instantiate (skill judgment)
- Manage a target directory (user already knows where they want it)

Each of those is friction. The model is already good at "copy this file and replace `YOUR_NAME` with the value the user gave me earlier." A generator script is over-engineering.

If users start hand-creating plugins frequently and templates accumulate boilerplate, revisit.

---

## Why `check-submission.sh` is the only script

Only one thing in this repo deserves a script:

- It's deterministic
- It's tedious
- It involves a network call (name availability)
- It produces output that goes directly into a form

Everything else — scaffolding, validation, deciding what to build — is either covered by the CLI or is judgment work for the skill.

If we add scripts later (e.g., `release.sh` to bump version + tag + create release), they go in `scripts/`. Scripts must be:
- Pure shell (no node_modules, no python venv)
- Single-purpose
- Idempotent
- Useful from outside this repo (someone with their own plugin can run them on it)

---

---

## Cross-surface testing — Claude Code vs Cowork

Plugins target two surfaces:
- **Claude Code** — CLI, scriptable. `claude plugin validate`, `claude --plugin-dir`, headless `-p` mode all available.
- **Claude Cowork** — desktop app (macOS/Windows). **No CLI. No `--plugin-dir`. No scriptable install.** Plugin install is `Cowork tab → Customize → Browse plugins → Install` (or upload a `.zip`).

The pipeline automates Code testing fully (`claude plugin validate` in `check-submission.sh`) and adds a portability heuristic that flags Code-only features (`hooks/`, `.lsp.json`, `monitors/`, `bin/`, `settings.json`) so the human knows what to manually verify in Cowork.

For Cowork itself: gated on `COWORK_TESTED=yes` env var. The script refuses to add "Claude Cowork" to the suggested Platforms output unless the human signed off that they actually tested it. This is the same shape as Anthropic's own honor-system Platforms field — but at least the script forces the choice to be deliberate.

**Computer Use for Cowork — available today (with caveats):** Claude Code ships a built-in `computer-use` MCP server (enable via `/mcp`) on macOS for Pro/Max plans, v2.1.85+, in interactive sessions only. With it enabled, Claude Code can open the Cowork desktop app, navigate Customize → Browse plugins, upload a .zip, run a smoke prompt, and screenshot the result — without leaving the terminal session.

What this means for the pipeline:
- We **cannot** make `check-submission.sh` drive Cowork end-to-end, because computer-use is interactive-only (no `-p` flag).
- We **can** have the script generate a paste-ready prompt that the user runs in an interactive Claude Code session to perform the Cowork test. The script then trusts a follow-up `COWORK_TESTED=yes` env var as the human's signed confirmation.

This is the v0.3.0 pattern: hand-off to Claude Code's own computer-use rather than re-implementing UI automation. If Anthropic ships a Cowork CLI or non-interactive computer-use mode, we fully automate the loop. Until then, the orchestrator is Claude Code and the human is the trigger.

---

## Anti-goals

- **Don't ship a GUI / TUI.** The skill is the interface.
- **Don't re-implement what `claude plugin validate` does.** Defer to it.
- **Don't generate plugins from a single command.** That's a generator framework, which is a different project shape than a guide.
- **Don't bundle component examples that are themselves real plugins.** Templates are stubs, not working code. Real examples live in real plugins (e.g., the user's `experimental-engineer` and `first-principles-review` repos).
- **Don't gate behavior on Anthropic policy changes.** When the submission form or marketplace structure changes, update reference docs + script. Don't try to abstract over future changes.

---

## When this doc and the code disagree

This doc is aspirational. Update it or fix the code so they match. If you're adding a new reference file, a new template type, or a new script — add a section here first explaining the *why*.
