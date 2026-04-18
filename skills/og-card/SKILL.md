---
name: og-card
description: Use when generating an Open Graph social-preview image (1200×630 PNG) for a Claude Code plugin repo, so link unfurls in Twitter / Slack / iMessage / LinkedIn / GitHub's social-preview slot render as a branded card instead of a grey placeholder. Invoked from Phase 5.5 of the `create-claude-plugin` skill when the user picks "Draft og-card now", or directly when the user says "make an og image", "og card", "social preview image", or "link unfurl card". Mirrors the Chrome Web Store `cws-screens` skill's shape: interview → typed config → render → PNG.
---

# og-card — generate a 1200×630 social-preview image

## Overview

A well-designed OG card is the single biggest lift for link-unfurl conversion. This skill interviews the user, writes a typed config to `marketing/og.config.mjs`, then rasterizes an SVG template to `assets/og.png` using `@resvg/resvg-js`.

**Why it's separate from `create-claude-plugin`:** this skill pulls in a Node dep (`@resvg/resvg-js`) and a render pipeline. Keeping it isolated means the main plugin-builder flow stays dep-free for users who don't want a card.

## When to use

- Phase 5.5 of `create-claude-plugin` when the user picks "Draft og-card now"
- User says "make an og image for this plugin" / "social preview card" / "og card"
- User wants to replace a grey GitHub social-preview placeholder with a real card

## Prerequisites

- Node ≥18 and npm on the user's machine
- First invocation runs `npm install` in this skill's directory (one-time, ~20s). Subsequent renders are ~1s.

If Node is missing, stop and tell the user: they need Node 18+ from nodejs.org. Don't try to shim around it.

## The interview

Ask these in one batch (`AskUserQuestion` if available, otherwise a compact message). Read `.claude-plugin/plugin.json` first — use `name` and `description` to seed defaults so the user can just confirm where possible.

| # | Question | Notes |
|---|---|---|
| 1 | **Category label** (uppercase above tagline) | e.g. `Claude plugin`, `Skill`, `Marketplace`. Keep ≤ 24 chars. |
| 2 | **Tagline line 1** (≤ 32 chars) | The headline. One idea. Name the category + unique move. |
| 3 | **Tagline line 2** (≤ 32 chars, optional) | Leave empty for a single-line headline. |
| 4 | **Subtitle** (≤ 90 chars) | One clarifying sentence — auto-wraps to 2 lines. |
| 5 | **Accent color** (hex) | Default `#5B7CFA`. Brand color if the user has one. |
| 6 | **Theme** | `light` or `dark`. Default `light`. |
| 7 | **Footer text** | Default `github.com/<owner>/<repo>` derived from `plugin.json.repository`. |

**Seeding from `plugin.json`:**
- `label` → default to `"Claude plugin"` if nothing else fits
- `taglineLine1/2` → derive from the first sentence of `description`, split at a natural break
- `subtitle` → second sentence of `description` (or a user-voiced outcome)
- `footer` → strip `https://github.com/` from `.repository`

Don't invent copy — if the existing README has a strong tagline from Phase 5.5, use it verbatim.

## Write the config

Copy `${CLAUDE_PLUGIN_ROOT}/skills/og-card/templates/og.config.mjs.tmpl` to the target plugin's `marketing/og.config.mjs`, then replace every `*_PLACEHOLDER` string with the user's answers. The renderer rejects any remaining placeholder strings before rasterizing, so this is a hard gate — don't ship placeholders.

## Render

```bash
${CLAUDE_PLUGIN_ROOT}/skills/og-card/scripts/render.sh <plugin-path>/marketing/og.config.mjs
```

- First invocation: installs `@resvg/resvg-js` in the skill dir (~20s, one-time).
- Writes `<plugin-path>/assets/og.png` (1200×630, ~50–120 KB depending on theme).
- Errors with a clear message on any `*_PLACEHOLDER` string.

## Present the result

After rendering, show the user the generated PNG (Read the file, or describe the layout) and offer:

- *"Ship it"* — keep as-is, return to Phase 5.5
- *"Tweak copy"* — edit `og.config.mjs` fields, re-render. Cap at 3 rounds
- *"Try dark theme"* / *"Try light theme"* — flip `theme` field, re-render
- *"Discard"* — delete `assets/og.png` and `marketing/og.config.mjs`, return to Phase 5.5

## Wire the PNG into the repo

After the user ships, make sure the card is discoverable:

1. **README hero slot** — insert `<p align="center"><img src="assets/og.png" alt="<plugin-name>" width="760"></p>` near the top of `README.md`, under the tagline. Only do this if the README doesn't already have a hero image.
2. **GitHub social-preview slot** — tell the user (don't try to automate): "Upload `assets/og.png` at `https://github.com/<owner>/<repo>/settings` → *Social preview* → *Edit*. GitHub's API doesn't expose this; it's manual one-time setup per repo."
3. **`MARKETING.md`** — remove the `<!-- TODO: og-card -->` block from `MARKETING.md` and replace with a one-line reference: `Social preview: assets/og.png (1200×630). Upload to GitHub repo settings → Social preview.`

## Common issues

| Symptom | Fix |
|---|---|
| Font looks like Times New Roman | `@resvg/resvg-js` couldn't find Inter or Helvetica. On Linux/Docker, install `fonts-inter` or bundle a TTF. On macOS this should work out of the box. |
| Text clips off the right edge | Tagline line > 32 chars, or subtitle > ~90 chars. Shorten, or split across both tagline lines. |
| `render.sh: first-run setup...` hangs | Network issue. Test with `npm ping` inside the skill dir. Don't run in a sandbox without network on first invocation. |
| Dark theme accent invisible | Accent color is too close to `#0B1020` (the bg). Pick a more saturated hue. |
| `render.mjs: still contains placeholder` | A `*_PLACEHOLDER` string wasn't replaced in `og.config.mjs`. Fix the specific field the error names. |

## What this skill does NOT do

- **Demo GIFs** — the `create-claude-plugin` plugin template already scaffolds a VHS tape at `docs/demo.tape`; that flow is separate.
- **Product Hunt / Hunt banners** — different aspect ratio; future work.
- **Animated / video cards** — SVG-to-PNG only.
- **Custom templates** — v1 ships two themes (`light`, `dark`). Custom designs are future work.
- **Upload to GitHub social-preview slot** — GitHub has no API for this. Tell the user where to click.

## Files this skill owns

```
skills/og-card/
├── SKILL.md                          # this file
├── package.json                      # @resvg/resvg-js dep
├── templates/
│   ├── default-light.svg             # light theme template (mustache-ish)
│   ├── default-dark.svg              # dark theme template (w/ accent glow)
│   └── og.config.mjs.tmpl            # typed config template for the user's plugin
└── scripts/
    ├── render.sh                     # shell wrapper — handles first-run install
    └── render.mjs                    # SVG template fill + resvg rasterize
```

Files this skill writes into the **user's** plugin:

```
<plugin-path>/
├── marketing/
│   └── og.config.mjs                 # the filled-in config (source of truth)
└── assets/
    └── og.png                        # the rasterized card (committed to git)
```
