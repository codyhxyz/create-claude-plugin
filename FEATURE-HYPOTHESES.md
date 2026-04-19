# CreateClaude — GitHub Publishing Feature Hypotheses

Living list of features we're testing to improve the GitHub-publishing side of CreateClaude. Each scaffolded plugin should end up with a repo that feels as polished and agent-friendly as [heygen-com/hyperframes](https://github.com/heygen-com/hyperframes).

This doc doubles as the working task list — update `status` in-place as features ship or get reconsidered.

## Locked design decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Hero asset format | VHS (`charmbracelet/vhs`) → `.gif` primary. Scaffold a `docs/demo.tape`. SVG wordmark only if VHS missing. |
| 2 | Meta-marketplace | **Yes — live.** Repo: `codyhxyz/codyhxyz-plugins` (marketplace name `codyhxyz-plugins`). Users run `/plugin marketplace add codyhxyz/codyhxyz-plugins` once, then install any listed plugin. |
| 3 | Topic list | Baseline `claude-code`, `claude-code-plugin`, `claude-plugin`. Auto-detect: `skills/` → `claude-skill`, `agents/` → `claude-agent`, `hooks/` → `claude-hook`, `.mcp.json` → `mcp`. Plus manifest `keywords`. |
| 4 | Badge version source | `img.shields.io/github/package-json/v` against `.claude-plugin/plugin.json`. |
| 5 | Publish script on re-run | Idempotent. Always `gh repo edit` whether the repo exists or not. |
| 6 | Dogfood target | `prompt-optimizer` README is the canary before template rollout. |

## Feature list

Status legend: `todo` · `in-progress` · `shipped` · `deferred` · `dropped`

### Phase A — Dogfood on prompt-optimizer

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| A1 | Restructure `prompt-optimizer/README.md` to hyperframes shape | shipped | `prompt-optimizer/README.md` | S | Tagline → badges → intro → Quick Start (3 options) → try-it → Why (4 bullets) → How it works → Grounding → `<details>` examples → Contributing → License |
| A2 | Add shield badges to prompt-optimizer README | shipped | `prompt-optimizer/README.md` | S | License (MIT), version via `github/package-json/v` pointed at `.claude-plugin/plugin.json`, "Built for Claude Code" |
| A3 | Set repo metadata on `codyhxyz/prompt-optimizer` via `gh repo edit` | shipped | GitHub | S | Description tightened; topics applied |
| A4 | Record VHS demo for prompt-optimizer | shipped | `prompt-optimizer/docs/demo.tape`, `docs/demo-session.sh`, `docs/hero.gif` | M | Rendered at 147k via `vhs docs/demo.tape`. VHS first render failed with `ttyd navigation: ERR_CONNECTION_REFUSED` — second run succeeded. Worth noting: VHS appears flaky on first spawn; retry-once is a reasonable default for the future `scripts/record-demo.sh`. |
| A5 | Commit + push dogfood to `codyhxyz/prompt-optimizer` | shipped | GitHub main | S | Commit `f10656f` — README rewrite + `docs/` hero pipeline |

### Phase B — Batch mechanical wins into CreateClaude template

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| B1 | `scripts/publish-to-github.sh` — idempotent `gh repo create` + `gh repo edit` reading `plugin.json` | shipped | `create-claude-plugin/scripts/publish-to-github.sh` | S | Sets description/homepage/topics (baseline + auto-detected + manifest keywords). C2 (tag + release from CHANGELOG) and E2 (auto-PR into `codyhxyz/codyhxyz-plugins`) are baked in. Skip either via `CCP_SKIP_RELEASE=1` / `CCP_SKIP_REGISTRY=1`. |
| B2 | Badge block in plugin README template | shipped | `create-claude-plugin/skills/create-claude-plugin/templates/plugin/README.md` | S | License/version/Built-for-Claude-Code badges, wrapped in `<!-- auto:start -->` / `<!-- auto:end -->` markers for C1 |
| B3 | Restructure plugin README template to hyperframes shape | shipped | same as B2 | S | Centered hero → badges → tagline → hero GIF → Quick Start (3 options with meta-marketplace as default) → Try it → Why → How → `<details>` examples → Contributing → License |
| B4 | `.github/` scaffold — issue forms, PR template, `CONTRIBUTING.md` | shipped | `create-claude-plugin/skills/create-claude-plugin/templates/plugin/.github/` | S | Bug form collects plugin version + `claude --version` + install path; PR template has test-plan checklist; CONTRIBUTING covers the dev loop + release flow |
| B5 | Rewrite SKILL.md Phase 6 to invoke `publish-to-github.sh` | shipped | `create-claude-plugin/skills/create-claude-plugin/SKILL.md:265-290` | S | Describes the four-step idempotent flow + env-var overrides. `reference/hosting-options.md:5-13` updated to match. |

### Phase C — Sync + automation

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| C1 | `scripts/sync-readme.sh` with `<!-- auto:start -->` / `<!-- auto:end -->` markers | shipped | `create-claude-plugin/scripts/sync-readme.sh` | M | Splices two marker-delimited blocks in the plugin README: header (title + badges + tagline + hero) and install (meta-marketplace + direct + local). Idempotent — no-ops if the README already matches `plugin.json`. |
| C2 | Tag + `gh release create` from CHANGELOG | shipped | bundled into B1 | S | `publish-to-github.sh` tags `v<version>`, pulls the matching CHANGELOG block, cuts a GitHub release. Idempotent on re-run. |
| C3 | Extend `scripts/check-submission.sh` — warn on missing badges, unset metadata, missing hero | shipped | `create-claude-plugin/scripts/check-submission.sh` | M | New "Repo polish (Phase 6):" section after the Cowork checks. Warns on: missing shield badges in README, no `docs/hero.*` asset, remote repo topics unset (via `gh repo view --json repositoryTopics`). Homepage already covered by existing warn on line 118. |

### Phase D — Hero pipeline

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| D1 | Scaffold `docs/demo.tape` template in plugin template | shipped | `create-claude-plugin/skills/create-claude-plugin/templates/plugin/docs/demo.tape` | M | Dracula theme, 1100×820, 30px padding, ~20s cap. Comments point users at `scripts/record-demo.sh` and the prompt-optimizer `demo-session.sh` pattern. |
| D2 | `scripts/record-demo.sh` wrapping `vhs` with fallback messaging | shipped | `create-claude-plugin/scripts/record-demo.sh` | S | Retry-once on `ERR_CONNECTION_REFUSED` / `navigation failed` / `recording failed` (learned from A4). Falls back to `generate-wordmark.sh` when VHS missing. |
| D3 | SVG wordmark generator (fallback only) | shipped | `create-claude-plugin/scripts/generate-wordmark.sh` | S | Reads `plugin.json` `name` + `description` → `docs/hero.svg`. Dracula-ish gradient background, XML-escapes user input. Smoke-tested against `<`/`>`/`&`/`"`/`'` in manifest strings. |

### Phase E — Meta-marketplace

| ID | Feature | Status | Location | Effort | Notes |
|---|---|---|---|---|---|
| E1 | Stand up `codyhxyz/codyhxyz-plugins` registry repo | shipped | https://github.com/codyhxyz/codyhxyz-plugins | S | Repo created, pushed, topics applied. First entry: `prompt-optimizer` via `{source: github, repo: codyhxyz/prompt-optimizer}`. Marketplace name: `codyhxyz-plugins`. README in hyperframes shape. |
| E2 | Auto-PR entry into registry from `publish-to-github.sh` | shipped | bundled into B1 | M | Clones the registry, upserts an entry in `.claude-plugin/marketplace.json` (source: github), opens a PR via `gh pr create`. Idempotent — skips if the entry is already current. |

## Hypotheses being tested

- **H1.** Every scaffolded plugin benefits from the same README shape — i.e. the hyperframes structure is general, not domain-specific.
- **H2.** Manifest (`plugin.json`) is the right single source of truth for description, topics, version, and homepage — no separate config needed.
- **H3.** Auto-detecting component-type topics from directory layout is accurate enough that owners never override it.
- **H4.** VHS produces hero assets of acceptable quality for Claude Code plugins, given that the natural demo is terminal/agent dialogue.
- **H5.** A single meta-marketplace materially reduces install friction when one author ships many plugins.
- **H6.** Idempotent re-runs of the publish script are better than a split "create / update" UX.

Revisit H3–H6 after Phase C + D ship and we have an end-to-end smoke-test plugin to look at.
