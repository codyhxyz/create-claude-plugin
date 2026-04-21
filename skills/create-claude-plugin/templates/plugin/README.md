<!-- auto:start — rewritten by scripts/sync-readme.sh from plugin.json; do not hand-edit between these markers -->
<h1 align="center">PLUGIN_NAME</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href=".claude-plugin/plugin.json"><img src="https://img.shields.io/github/package-json/v/YOUR_GH_USER/PLUGIN_NAME?filename=.claude-plugin%2Fplugin.json&label=version" alt="Version"></a>
  <a href="https://claude.com/product/claude-code"><img src="https://img.shields.io/badge/built_for-Claude%20Code-d97706" alt="Built for Claude Code"></a>
</p>

<p align="center"><b>ONE_LINE_TAGLINE — the "X in, Y out" hook.</b></p>

<p align="center">
  <img src="docs/hero.gif" alt="PLUGIN_NAME demo" width="900">
</p>
<!-- auto:end -->

ONE_PARAGRAPH_INTRO — what problem this solves, who it's for, and why it's worth the install. Lead with the user's pain, not the plugin's features.

## Quick Start

<!-- auto:start-install — rewritten by scripts/sync-readme.sh -->
### Option 1 — install from the codyhxyz-plugins marketplace *(recommended)*

```
/plugin marketplace add codyhxyz/codyhxyz-plugins && /plugin install PLUGIN_NAME@codyhxyz-plugins
```

### Option 2 — install directly from this repo

```
/plugin marketplace add YOUR_GH_USER/PLUGIN_NAME && /plugin install PLUGIN_NAME@PLUGIN_NAME
```

### Option 3 — local smoke test

```bash
git clone https://github.com/YOUR_GH_USER/PLUGIN_NAME
claude --plugin-dir ./PLUGIN_NAME
```
<!-- auto:end-install -->

## Try it — paste any of these

> "Example user prompt 1"

> "Example user prompt 2"

> "Example user prompt 3"

## Why PLUGIN_NAME?

- **REASON_1** — concrete benefit, not a feature restatement.
- **REASON_2** — what it replaces or removes from your workflow.
- **REASON_3** — the judgment call the plugin makes for you.
- **REASON_4** — where it stops, so people know what it *doesn't* try to be.

## How it works

BRIEF_MECHANISM — one short paragraph. What triggers the plugin, what it reads, what it writes. Link to the skill/agent body for depth.

## Examples

<details>
<summary><b>Scenario 1</b> — "Representative user request"</summary>

<br>

CONCRETE_BEFORE_AFTER — a real user prompt, what the plugin did, and the outcome. Keep it specific enough that a reader can picture themselves in it.

</details>

<details>
<summary><b>Scenario 2</b> — "Another representative user request"</summary>

<br>

ANOTHER_SCENARIO — different enough from Scenario 1 that it widens the reader's sense of what this is good for.

</details>

## Contributing

Issues and PRs welcome. See `.github/CONTRIBUTING.md`. If `PLUGIN_NAME` misses a failure mode you keep hitting, file it with a before/after — that's a bug.

## License

[MIT](LICENSE) © YEAR YOUR_NAME
