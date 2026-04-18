# CreateClaude — GitHub Publishing Feature Hypotheses

Living list of features we're testing to improve the GitHub-publishing side of CreateClaude. Each scaffolded plugin should end up with a repo that feels as polished and agent-friendly as [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes).

This doc doubles as the working task list — update `status` in-place as features ship or get reconsidered.

## Locked design decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Hero asset format | VHS (`charmbracelet/vhs`) → `.gif` primary + `.webm` fallback. Scaffold a `docs/demo.tape`. SVG wordmark only if VHS missing. |
| 2 | Meta-marketplace | **Yes — live.** Repo: `codyhxyz/claude-plugins` (marketplace name `codyhxyz-plugins`). Users run `/plugin marketplace add codyhxyz/claude-plugins` once, then install any listed plugin. |
| 3 | Topic list | Baseline `claude-code`, `claude-code-plugin`, `claude-plugin`, `agent`. Auto-detect: `skills/` → `claude-skill`, `agents/` → `claude-agent`, `hooks/` → `claude-hook`, `.mcp.json` → `mcp`. Plus manifest `keywords`. |
| 4 | Badge version source | `img.shields.io/github/package-json/v` against raw `plugin.json`. |
| 5 | Publish script on re-run | Idempotent. Always `gh repo edit` whether the repo exists or not. |
| 6 | Dogfood target | `prompt-optimizer` README is the canary before template rollout. |

## Feature list

Status legend: `todo` · `in-progress` · `shipped` · `deferred` · `dropped`

### Phase A — Dogfood on prompt-optimizer

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| A1 | Restructure `prompt-optimizer/README.md` to hyperframes shape | shipped | `prompt-optimizer/README.md` | S | Tagline → badges → intro → Quick Start (3 options) → try-it → Why (4 bullets) → How it works → Grounding → `<details>` examples → Contributing → License |
| A2 | Add shield badges to prompt-optimizer README | shipped | `prompt-optimizer/README.md` | S | License (MIT), version via `github/package-json/v` pointed at `.claude-plugin/plugin.json`, "Built for Claude Code" |
| A3 | Set repo metadata on `codyhxyz/prompt-optimizer` via `gh repo edit` | shipped | GitHub | S | Description tightened; topics applied: `claude-code, claude-code-plugin, claude-plugin, claude-agent, agent, prompt-engineering, prompt-optimization, meta`. Homepage intentionally empty (matches hyperframes). |
| A4 | Record VHS demo for prompt-optimizer | shipped | `prompt-optimizer/docs/demo.tape`, `docs/demo-session.sh`, `docs/hero.gif` | M | Rendered at 147k via `vhs docs/demo.tape`. README now embeds `<img src="docs/hero.gif">`. VHS first render failed with a `ttyd navigation: ERR_CONNECTION_REFUSED` — second run succeeded cleanly. Worth noting: VHS appears flaky on first spawn after install; retry-once is a reasonable default for the future `scripts/record-demo.sh`. |

### Phase B — Batch mechanical wins into CreateClaude template

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| B1 | `scripts/publish-to-github.sh` — idempotent `gh repo create` + `gh repo edit` reading `plugin.json` | todo | `create-claude-plugin/scripts/publish-to-github.sh` | S | Sets description/homepage/topics (baseline + auto-detected + manifest keywords) |
| B2 | Badge block in plugin README template | todo | `create-claude-plugin/skills/create-claude-plugin/templates/plugin/README.md` | S | Placeholders substituted by the skill at scaffold |
| B3 | Restructure plugin README template to hyperframes shape | todo | same as B2 | S | Mirror what we ship in A1 |
| B4 | `.github/` scaffold — issue forms, PR template, `CONTRIBUTING.md` | todo | `create-claude-plugin/skills/create-claude-plugin/templates/plugin/.github/` | S | Issue forms include `plugin version` + `claude --version` fields |
| B5 | Rewrite SKILL.md Phase 6 to invoke `publish-to-github.sh` | todo | `create-claude-plugin/skills/create-claude-plugin/SKILL.md:226-244` | S | Replaces the two inline `gh` commands |

### Phase C — Sync + automation

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| C1 | `scripts/sync-readme.sh` with `<!-- auto:start -->` / `<!-- auto:end -->` markers | todo | `create-claude-plugin/scripts/sync-readme.sh` | M | Reads `plugin.json` → rewrites badges + install block |
| C2 | Tag + `gh release create` from CHANGELOG | todo | extends B1 | S | Runs after first push |
| C3 | Extend `scripts/check-submission.sh` — warn on missing badges, unset metadata, missing hero | todo | `create-claude-plugin/scripts/check-submission.sh` | M | |
| C4 | Add `/humanizer` pass to automated pipeline | todo | `create-claude-plugin/scripts/check-submission.sh` (and publish handoff) | M | Humanize final README/manifest outputs before submission-open handoff, then keep human review checkpoints explicit |

### Phase D — Hero pipeline

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| D1 | Scaffold `docs/demo.tape` template in plugin template | todo | `create-claude-plugin/skills/create-claude-plugin/templates/plugin/docs/demo.tape` | M | Taste-heavy: default script shape |
| D2 | `scripts/record-demo.sh` wrapping `vhs` with fallback messaging | todo | `create-claude-plugin/scripts/record-demo.sh` | S | Fallback to SVG wordmark generator if VHS missing |
| D3 | SVG wordmark generator (fallback only) | todo | `create-claude-plugin/scripts/generate-wordmark.sh` | S | Reads plugin name → outputs `docs/hero.svg` |

### Phase E — Meta-marketplace (contingent)

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| E1 | Stand up `codyhxyz/claude-plugins` registry repo | shipped | https://github.com/codyhxyz/claude-plugins | S | Repo created, pushed, 6 topics applied. First entry: `prompt-optimizer` via `{source: github, repo: codyhxyz/prompt-optimizer}`. marketplace name `codyhxyz-plugins`. README in hyperframes shape. |
| E2 | Auto-PR entry into registry from `publish-to-github.sh` | todo | extends B1 | M | Each new plugin appends one entry to the registry's `.claude-plugin/marketplace.json` via PR. |

## Hypotheses being tested

- **H1.** Every scaffolded plugin benefits from the same README shape — i.e. the hyperframes structure is general, not domain-specific.
- **H2.** Manifest (`plugin.json`) is the right single source of truth for description, topics, version, and homepage — no separate config needed.
- **H3.** Auto-detecting component-type topics from directory layout is accurate enough that owners never override it.
- **H4.** VHS produces hero assets of acceptable quality for Claude Code plugins, given that the natural demo is terminal/agent dialogue.
- **H5.** A single meta-marketplace materially reduces install friction when one author ships many plugins.
- **H6.** Idempotent re-runs of the publish script are better than a split "create / update" UX.

Revisit H3–H6 after Phase B ships and we have real repo outputs to look at.
