# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-04-16

### Added
- Initial release of the `create-claude-plugin` orchestration skill.
- Reference docs for `plugin.json`, `marketplace.json`, component types, hosting options, and the official submission form.
- Templates for `plugin.json`, `marketplace.json`, README, LICENSE, CHANGELOG, `.gitignore`, plus skill/agent/hook starters.
- `scripts/check-submission.sh` — pre-flight script that verifies every submission-form field is present and prints them paste-ready.
- Pre-publish + submission-ready checklists.
- `.claude-plugin/marketplace.json` so the repo is installable via `/plugin marketplace add`.
