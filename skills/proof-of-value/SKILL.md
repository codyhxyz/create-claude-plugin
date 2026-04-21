---
name: proof-of-value
description: Use when generating a proof-of-value artifact for a Claude Code plugin — a visual before/after, benchmark chart, terminal diff, output-quality comparison, coverage checklist, or file-tree diff — so the README answers "what does this plugin give me that I can't already do?" with evidence instead of adjectives. Invoked from Phase 5.5 of the `create-claude-plugin` skill, or directly when the user says "prove the value", "add a demo", "before after", "benchmark image", "show the proof", "receipts", "show me it works".
---

# proof-of-value — render one artifact that proves the plugin's value

## Overview

Every good plugin README has to answer one question in under five seconds:

> **"What does this plugin give me that I can't already do?"**

Adjectives don't answer it. Evidence does. This skill picks the right *shape* of evidence for the plugin, fills a typed config, and rasterizes an SVG template to `assets/proof-of-value.png`.

Six shapes. One artifact. One README slot. The author's only decision is *which shape fits*.

**Why it's separate from `create-claude-plugin`:** this skill pulls in a Node dep (`@resvg/resvg-js`) and a render pipeline. Keeping it isolated means the main plugin-builder flow stays dep-free for authors who don't want an auto-generated image.

## When to use

- Phase 5.5 of `create-claude-plugin` — required before Phase 6 (Host)
- User says "add a demo", "before after", "prove the value", "show me it works", "receipts", "benchmark chart"
- User is about to submit to the official marketplace and `check-submission.sh` flagged missing `assets/proof-of-value.png`

## The six kinds

| `kind` | Plugin shape | What renders |
|---|---|---|
| `visual` | Design / UX / visual polish | Before + after screenshots, side-by-side |
| `benchmark` | Performance / token / latency | Paired horizontal bars with numbers + delta |
| `terminal-diff` | Workflow / keystroke reduction | Two terminal panels — N commands vs. 1 |
| `output-quality` | Prompt / agent / quality uplift | Two prose panels — raw LLM vs. plugin-guided |
| `coverage` | Scope / completeness | Checklist — covered (✓) vs. not (✕) |
| `file-tree` | Scaffolding / architectural | Two tree panels — before / after |

## Prerequisites

- Node ≥ 18 and npm on the user's machine
- First invocation runs `npm install` in this skill's directory (one-time, ~20s). Subsequent renders are ~1s.

If Node is missing, stop and tell the user: they need Node 18+ from nodejs.org. Don't try to shim around it.

## The interview

### Step 1 — classify the plugin (the only step that matters)

Ask the author, in one batch:

> *What does this plugin give the user that they can't already do? Pick the closest:*
>
> 1. Makes something look / feel better → **visual**
> 2. Makes something faster / cheaper / smaller → **benchmark**
> 3. Replaces many steps with one → **terminal-diff**
> 4. Produces better output than raw LLM → **output-quality**
> 5. Covers a checklist of things the LLM usually forgets → **coverage**
> 6. Changes code / file structure → **file-tree**
> 7. **None of these — I can't pick one cleanly**

If the author picks **7**, stop. Tell them:

> *If you can't pick a kind, the plugin's value prop isn't crisp enough to ship. "Makes your workflow better" is not a value prop — it's an adjective. Before running this skill, write one sentence that names the delta: "Before this plugin: X. After: Y." If you can do that, the kind picks itself. If you can't, the plugin isn't ready.*

Do not render anything in this branch. Return to the parent skill with a note that Phase 5.5 is blocked on value-prop clarity.

### Step 2 — fill the kind-specific fields

Ask only the questions for the chosen kind. Read `.claude-plugin/plugin.json` first to seed `name` and `caption` from the description.

**Shared (all kinds):**
- `name` — plugin name (seeds from `plugin.json`)
- `caption` — one line under the image in the README, ≤ 120 chars. State the delta.
- `theme` — `light` or `dark` (default `light`; match the og-card if one exists)
- `accent` — hex color (match the og-card accent if present)

**kind-specific:**

| kind | fields |
|---|---|
| `visual` | `beforeImage`, `afterImage` (paths relative to config file; PNG/JPG/WebP) |
| `benchmark` | `unit` (e.g. `"tokens"`, `"ms"`), `lowerIsBetter` (bool), `rows: [{ label, before, after }]` — up to 6 |
| `terminal-diff` | `beforeLabel`, `afterLabel`, `before`, `after` (multiline strings, ≤ 18 lines × 56 chars) |
| `output-quality` | `userPrompt` (optional shared prompt), `beforeLabel`, `afterLabel`, `before`, `after` (≤ 600 chars each) |
| `coverage` | `heading`, `rows: [{ label, covered: true\|false }]` — up to 12 |
| `file-tree` | `beforeLabel`, `afterLabel`, `before`, `after` (tree-formatted text, ≤ 18 lines × 56 chars) |

Don't invent numbers. If the author doesn't have real benchmark data, **don't ship a benchmark kind** — pick a different shape or say the plugin isn't ready.

## Write the config

Copy `${CLAUDE_PLUGIN_ROOT}/skills/proof-of-value/templates/proof-of-value.config.mjs.tmpl` to the target plugin's `marketing/proof-of-value.config.mjs`, then replace:

- `KIND_PLACEHOLDER` with the chosen kind string
- `PLUGIN_NAME_PLACEHOLDER` with the plugin's `name`
- `CAPTION_PLACEHOLDER` with the one-line caption
- Fill only the block matching the chosen `kind`; leave the rest.

The renderer rejects `*_PLACEHOLDER` strings in `kind`, `name`, and `caption` — it's a hard gate.

## Render

```bash
${CLAUDE_PLUGIN_ROOT}/skills/proof-of-value/scripts/render.sh <plugin-path>/marketing/proof-of-value.config.mjs
```

- First invocation: installs `@resvg/resvg-js` in the skill dir (~20s, one-time).
- Writes `<plugin-path>/assets/proof-of-value.png` (1600×900, ~60–180 KB).
- Errors with a clear message on unknown kind, placeholder strings, or missing images.

## Present the result

After rendering, show the user the generated PNG and offer:

- *"Ship it"* — keep as-is, return to Phase 5.5
- *"Tweak copy / numbers"* — edit `proof-of-value.config.mjs`, re-render. Cap at 3 rounds.
- *"Try dark theme"* / *"Try light theme"* — flip `theme`, re-render
- *"Change kind"* — re-interview from Step 1
- *"Discard"* — delete `assets/proof-of-value.png` and `marketing/proof-of-value.config.mjs`, return to Phase 5.5

## Wire the PNG into the repo

The template scaffolded by `create-claude-plugin` already has an `<!-- auto:start-proof-of-value -->` block in the README that `scripts/sync-readme.sh` populates. After rendering:

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-readme.sh <plugin-path>` to fill the block with `<img src="assets/proof-of-value.png" ...>` + the caption.
2. Commit both `assets/proof-of-value.png` and `marketing/proof-of-value.config.mjs` (the config is the source of truth — re-renders are reproducible).

If the plugin pre-dates the new README template, insert this snippet manually under the hero:

```html
<p align="center">
  <img src="assets/proof-of-value.png" alt="PLUGIN_NAME — proof of value" width="900">
</p>
<p align="center"><em>CAPTION</em></p>
```

## Common issues

| Symptom | Fix |
|---|---|
| `invalid kind "..."` | Set `kind` to one of `visual`, `benchmark`, `terminal-diff`, `output-quality`, `coverage`, `file-tree`. |
| `benchmark kind requires at least one row` | Add entries to `benchmark.rows`. If you don't have real data, pick a different kind. |
| Visual mode: image text is unreadable | Source images should be ≥ 1400 px wide for 1:1 panel rendering. |
| Text clips off the right edge (terminal / tree) | > 56 chars/line or > 18 lines. Trim, or move detail to the README body. |
| Output-quality text truncated with `…` | Panels cap at 16 lines × 46 chars. Cut to the essential contrast. |
| Font renders as Times New Roman | resvg couldn't find Inter or Helvetica. Install `fonts-inter` (Linux) or bundle a TTF. macOS works out of the box. |
| Dark theme bars invisible | Accent too close to `#0B1020`. Pick a more saturated hue. |

## What this skill does NOT do

- **Auto-classify plugin shape.** The author picks. Auto-detect is brittle and bypasses the judgment step that's the whole point.
- **Plot arbitrary chart types.** Six fixed SVG templates; no plotting library. If the data doesn't fit one of the six, the plugin probably doesn't need this artifact.
- **Animate.** SVG-to-PNG only. Demo GIFs are a separate concern (`docs/demo.tape` in the `create-claude-plugin` template).
- **Host the image.** Commit the PNG to the repo. GitHub's raw URL is the CDN.
- **Decide whether the plugin is worth shipping.** That's on the author. This skill just makes it visible when the answer is "no".

## Files this skill owns

```
skills/proof-of-value/
├── SKILL.md                                     # this file
├── package.json                                 # @resvg/resvg-js dep
├── templates/
│   ├── proof-of-value.config.mjs.tmpl           # typed config — user copies this
│   ├── visual.svg
│   ├── benchmark.svg
│   ├── terminal-diff.svg
│   ├── output-quality.svg
│   ├── coverage.svg
│   └── file-tree.svg
└── scripts/
    ├── render.sh                                # shell wrapper — handles first-run install
    └── render.mjs                               # kind-switched SVG fill + resvg rasterize
```

Files this skill writes into the **user's** plugin:

```
<plugin-path>/
├── marketing/
│   └── proof-of-value.config.mjs                # the filled-in config (source of truth)
└── assets/
    └── proof-of-value.png                       # the rasterized artifact (commit this)
```
