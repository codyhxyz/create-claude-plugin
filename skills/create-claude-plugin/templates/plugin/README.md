# PLUGIN_NAME

> ONE_SENTENCE_ELEVATOR_PITCH

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/github/package-json/v/YOUR_GH_USER/PLUGIN_NAME?filename=.claude-plugin/plugin.json)](.claude-plugin/plugin.json)
[![Built for Claude Code](https://img.shields.io/badge/built%20for-Claude%20Code-6B4FBB)](https://docs.claude.com/claude-code)

<!--
  Hero asset: record a short demo with VHS (charmbracelet/vhs) and commit it as `docs/hero.gif`.
  See `docs/demo.tape` for the tape file. Once committed, replace this comment with:

  <p align="center"><img src="docs/hero.gif" alt="PLUGIN_NAME demo" width="760"></p>

  If you don't have a GIF yet, leave the comment and lead with the tagline above.
-->

ONE_PARAGRAPH_INTRO — what problem this solves, who it's for, and why it's worth the install. Lead with the user's pain, not the plugin's features.

## Quick Start

### Claude Code (recommended)

```
/plugin marketplace add YOUR_GH_USER/PLUGIN_NAME
/plugin install PLUGIN_NAME@PLUGIN_NAME
```

### Manual install (single skill/agent)

```bash
mkdir -p ~/.claude/skills/PLUGIN_NAME
curl -fsSL https://raw.githubusercontent.com/YOUR_GH_USER/PLUGIN_NAME/main/skills/PLUGIN_NAME/SKILL.md \
  -o ~/.claude/skills/PLUGIN_NAME/SKILL.md
```

### Try it locally before installing

```bash
git clone https://github.com/YOUR_GH_USER/PLUGIN_NAME
cd PLUGIN_NAME
claude --plugin-dir ./
```

## Why

- **REASON_1** — concrete benefit, not a feature restatement
- **REASON_2** — what it replaces or removes from your workflow
- **REASON_3** — the judgment call the plugin makes for you
- **REASON_4** — where it stops (so people know what it *doesn't* try to be)

## How it works

BRIEF_MECHANISM — one short paragraph. What triggers the plugin, what it reads, what it writes. Link to `ARCHITECTURE.md` or the skill body for depth.

## Examples

> **Example 1:** CONCRETE_BEFORE_AFTER — a real user prompt, what the plugin did, and the outcome. Keep it specific enough that a reader can picture themselves in it.

> **Example 2:** ANOTHER_SCENARIO — different enough from Example 1 that it widens the reader's sense of what this is good for.

## Contributing

Issues and PRs welcome. See `CONTRIBUTING.md` if present, otherwise: open an issue describing what you'd change before sending a large PR.

## License

[MIT](LICENSE) © YEAR YOUR_NAME
