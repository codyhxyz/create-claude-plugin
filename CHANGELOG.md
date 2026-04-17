# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-04-16

### Added
- **Cross-surface portability check** in `check-submission.sh`: detects which plugin features are likely Code-only (hooks, LSP, monitors, `bin/`, `settings.json`) vs portable to Cowork (skills, agents, MCP). Prints a per-feature verdict.
- **Cowork manual-test gate**: `check-submission.sh` refuses to suggest "Claude Cowork" in the Platforms output unless `COWORK_TESTED=yes` env var confirms the human ran a manual install + smoke test in the Claude desktop app.
- New SKILL.md sub-phases **4a (Claude Code, automated)** and **4b (Claude Cowork, manual)** with the Customize → Browse plugins flow documented.
- `reference/submission-form.md` Platforms section now documents Claude Code vs Cowork install/test differences.
- `checklists/submission-ready.md` Platforms now has per-surface sub-checkboxes.
- `ARCHITECTURE.md` notes Computer Use as future work for closing Cowork's automation gap.

## [0.1.0] — 2026-04-16

### Added
- Initial release of the `create-claude-plugin` orchestration skill.
- Reference docs for `plugin.json`, `marketplace.json`, component types, hosting options, and the official submission form.
- Templates for `plugin.json`, `marketplace.json`, README, LICENSE, CHANGELOG, `.gitignore`, plus skill/agent/hook starters.
- `scripts/check-submission.sh` — pre-flight script that verifies every submission-form field is present and prints them paste-ready.
- Pre-publish + submission-ready checklists.
- `.claude-plugin/marketplace.json` so the repo is installable via `/plugin marketplace add`.
