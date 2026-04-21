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

<!-- auto:start-install — rewritten by scripts/sync-readme.sh -->
```
/plugin marketplace add codyhxyz/codyhxyz-plugins && /plugin install PLUGIN_NAME@codyhxyz-plugins
```
<!-- auto:end-install -->

<!-- auto:start-proof-of-value — rewritten by scripts/sync-readme.sh from marketing/proof-of-value.config.mjs -->
<p align="center"><em>(Run the <code>proof-of-value</code> skill to generate an artifact that answers <b>what does this plugin give me that I can't already do?</b>)</em></p>
<!-- auto:end-proof-of-value -->

ONE_PARAGRAPH_INTRO — what problem this solves, who it's for, and why it's worth the install. Lead with the user's pain, not the plugin's features.

<details>
<summary>Other install paths</summary>

<br>

**From this repo directly:**

```
/plugin marketplace add YOUR_GH_USER/PLUGIN_NAME && /plugin install PLUGIN_NAME@PLUGIN_NAME
```

**Local smoke test:**

```bash
git clone https://github.com/YOUR_GH_USER/PLUGIN_NAME
claude --plugin-dir ./PLUGIN_NAME
```

</details>

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

**User:** "A real prompt or workflow entry point — quoted, in the user's voice."
**Without PLUGIN_NAME:** What they'd get or have to do on their own — the friction, missing step, or wrong output.
**With PLUGIN_NAME:** The delta — one line, specific, no adjectives.

</details>

<details>
<summary><b>Scenario 2</b> — "Another representative user request"</summary>

<br>

**User:** "A different prompt, ideally showing a different failure mode than Scenario 1."
**Without PLUGIN_NAME:** …
**With PLUGIN_NAME:** …

</details>

## Contributing

Issues and PRs welcome. See `.github/CONTRIBUTING.md`. If `PLUGIN_NAME` misses a failure mode you keep hitting, file it with the user prompt + expected vs actual — that's a bug.

## License

[MIT](LICENSE) © YEAR YOUR_NAME
