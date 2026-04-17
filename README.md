# create-claude-plugin

> End-to-end skill for building a Claude Code plugin: scaffold → build → test → host on GitHub → submit to the official Anthropic marketplace.

The other plugin guides tell you what plugins *are*. This one walks you all the way through making one and getting it listed at `claude-plugins-official`, including the submission form's exact fields.

## What you get

- A **skill** (`/create-claude-plugin:create-claude-plugin`) that orchestrates the full creation process — installable via `/plugin marketplace add codyhxyz/create-claude-plugin`
- **Reference docs** for the `plugin.json` schema, `marketplace.json` schema, every component type (skills, agents, hooks, MCP, LSP, monitors, settings), hosting options, and the submission form
- **Templates** for `plugin.json`, `marketplace.json`, README, LICENSE, CHANGELOG, plus skill/agent/hook starters
- A **`check-submission.sh`** script that extracts every submission-form field from your plugin and prints them paste-ready
- **Checklists** for pre-publish + submission-ready

## Why a skill, not a CLI generator?

Plugin creation is mostly *judgment* — naming, scoping, picking components, writing a description that's actually a good description. The Claude CLI already handles validation (`claude plugin validate`). What was missing: a guide that closes the loop from "what is this thing" → "it's live in `claude-plugins-official`."

Like [chrome-extension-factory](https://github.com/codyhxyz/chrome-extension-factory), this leans on **scripts where determinism matters and the model where judgment matters.** The script catches missing fields. The skill helps you decide what those fields should *say*.

## Installation

### Claude Code (recommended)

```
/plugin marketplace add codyhxyz/create-claude-plugin
/plugin install create-claude-plugin@create-claude-plugin
```

### Manual install

```bash
mkdir -p ~/.claude/skills/create-claude-plugin
git clone https://github.com/codyhxyz/create-claude-plugin /tmp/ccp
cp -r /tmp/ccp/skills/create-claude-plugin/* ~/.claude/skills/create-claude-plugin/
```

## Usage

Just ask Claude Code to make a plugin:

> "Help me make a Claude Code plugin out of this skill I have in my `.claude/` dir."

> "I want to publish my code-review agent to the official Claude marketplace."

> "Scaffold a new Claude plugin with a skill and a hook."

The skill activates automatically and walks you through the seven phases (decide → scaffold → build → test → document → host → submit).

## Pre-flighting a submission

If you already have a plugin and just want to verify it's submission-ready:

```bash
./scripts/check-submission.sh /path/to/your/plugin
```

The script:
1. Validates `plugin.json` has every field the submission form needs
2. Checks the name is kebab-case, not reserved, not impersonating, and **not already taken in `claude-plugins-official`**
3. Confirms your README has an `## Examples` section
4. Runs `claude plugin validate` if available
5. Prints every field paste-ready for the form

## Repository layout

```
create-claude-plugin/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── create-claude-plugin/
│       ├── SKILL.md                    # main orchestration skill
│       ├── reference/                  # load on demand
│       │   ├── plugin-manifest.md
│       │   ├── marketplace-manifest.md
│       │   ├── component-types.md
│       │   ├── hosting-options.md
│       │   └── submission-form.md
│       ├── templates/                  # copy + fill in
│       │   ├── plugin/                 # plugin.json, marketplace.json, README, LICENSE, CHANGELOG, .gitignore
│       │   ├── skill/SKILL.md
│       │   ├── agent/agent.md
│       │   └── hook/hooks.json
│       └── checklists/
│           ├── pre-publish.md
│           └── submission-ready.md
├── scripts/
│   └── check-submission.sh
├── ARCHITECTURE.md
├── README.md
├── LICENSE
├── CHANGELOG.md
└── .gitignore
```

## Examples

> **Example 1:** "I have a code-review agent in `.claude/agents/` and I want to share it." — The skill walks you through converting the agent file into a plugin layout, scaffolds `.claude-plugin/plugin.json` + `marketplace.json`, sets up a README with install instructions, runs `claude plugin validate`, pushes to GitHub, and prints the exact text to paste into the official marketplace submission form.

> **Example 2:** "Build me a plugin from scratch that bundles a SKILL and a PostToolUse hook." — Skill picks the right component layout (skill at `skills/<name>/SKILL.md`, hook at `hooks/hooks.json`), scaffolds with `${CLAUDE_PLUGIN_ROOT}` substitutions in the hook so it works after install, runs the local `claude --plugin-dir` test loop, then guides hosting + submission.

## Contributing

Issues and PRs welcome. If a docs link in the skill or reference goes stale, that's a bug — file an issue or send a PR.

## License

[MIT](LICENSE) © 2026 Cody Hergenroeder
