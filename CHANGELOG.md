# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.1] — 2026-10-29

### Added
- **Listing-copy lint in `check-submission.sh`.** The plugin.json description, marketplace.json descriptions and README prose are checked for template residue (`Lorem ipsum` in any case; `TODO`, `TBD`, `FIXME` in uppercase only) and test wording ("debug build", "for testing purposes"), which warn, and for unfinished-feature wording ("coming soon", "public beta", "pre-release"), which is info only. Each finding names the field (with the README line), the matched text and the fix. Matching is word-bounded, and README fenced code blocks, inline code and HTML comments are skipped. Ported from the content checks in `asc validate`.
- **`check-submission.sh --strict`** turns the listing-copy warnings into errors for CI. Without it, the classic invocation behaves as before.
- **`publish-to-github.sh --dry-run`** (or `CCP_DRY_RUN=1`) runs only the reads (auth, repo, tag and release lookups, a throwaway registry clone) and prints every `gh` and `git` write it would make, including the registry entry it would PR.
- When a `publish-to-github.sh` command fails, it checks the githubstatus.com status API and says whether GitHub has an open incident or the failure is local.
- The skill's quick reference has a **Mutates** column (no / local / remote) so an agent knows which commands to confirm or dry-run first.

## [0.5.0] — 2026-10-29

### Added
- **`og-card --video`** renders `assets/og.mp4` next to `og.png`: a 4 s silent H.264 loop (High, yuv420p, BT.709, faststart) for `og:video` on hosted pages. Plays inline in iMessage, Discord and Telegram; everything else shows the PNG poster. The animation is periodic and equals the static card at phase 0, so `og.png` is frame 0 and the loop has no cut; the renderer refuses a clip that doesn't return to frame 0 or exceeds 2.5 MB. The static PNG is pixel-identical to before.
- `check-submission.sh` reports `assets/og.mp4` when present.
- Verified with Apple's LinkPresentation framework (what Messages uses): the clip is picked up from hosts that answer `Range` with 206 (Vercel, Netlify, R2 behind a Worker) and dropped from Cloudflare Pages and Workers static assets, which return 200. The skill now says so.

### Changed
- License is AGPL-3.0 (relicensed from MIT in June); `plugin.json` and the README badge still said MIT and now match `LICENSE`.

## [0.4.1] — 2026-04-24

### Fixed
- **SessionStart fork bomb in plugin-source dirs.** `session-start-banner.sh` invoked `check-submission.sh`, which spawned a nested `claude plugin validate .` to populate Phase 4 status. The nested `claude` fired its own `SessionStart`, re-entering the banner script and recursing — each level also fanned out to sibling SessionStart hooks (e.g. audio plugins → `afplay`), which in tight succession could overflow CoreAudio. Two-layer fix: (a) `session-start-banner.sh` now exports a `CCP_BANNER_GUARD=1` env var and bails on re-entry, (b) `check-submission.sh` skips the nested `claude plugin validate` entirely when `--quiet` is set (banner mode), since banner output never surfaces validator detail anyway. Phase 4 now reports `⚠ validate skipped in banner mode` instead of a false `✗`. Re-run without `--quiet` to get real validator status.

## [0.4.0] — 2026-04-17

### Added
- **Project-local `CLAUDE.md` template** at `skills/create-claude-plugin/templates/plugin/CLAUDE.md`. SKILL.md Phase 2 now copies it into every scaffolded plugin. Future sessions opened inside the plugin dir auto-read it on startup, so the directory invariants, path rules, naming rules, manifest rules, and always-run commands persist across days and sessions without the user re-invoking the skill.
- **Phase 0 expanded to cover mid-development resume** in SKILL.md. Existing Phase 0 (update an already-published plugin) is now Phase 0b; new Phase 0a handles the week-later case where a user is picking up work on a plugin they scaffolded in a prior session. Skill description broadened to trigger on phrases like "what's left on my plugin", "plugin status", "am I ready to submit", "resume my plugin".
- **`--status` mode for `check-submission.sh`.** Runs the same checks but tolerates incomplete state (exit 0), groups output by the 7 phases of the skill, and skips the clipboard/open handoff. Use mid-development to answer "what's left?". Adds a companion `--quiet` flag that collapses the report to a one-line banner for SessionStart hook use. Status-mode output surfaces the first truly-blocked phase (✗) separately from partial/unverified phases (⚠).
- **SessionStart hook + banner script.** New `hooks/hooks.json` registers a SessionStart hook that runs `scripts/session-start-banner.sh`. The banner script exits silently (and fast) when cwd isn't a plugin; when it is, it runs `check-submission.sh --status --quiet --offline` with a 5s timeout and prints a one-line banner only if a phase is truly blocked. Silence-is-golden on clean plugins.
- **CLAUDE.md check** added to `check-submission.sh` (warn-only to avoid regressing pre-0.4.0 plugins) and to `checklists/pre-publish.md`.
- Repo-root `CLAUDE.md` for the meta-plugin itself — same rules this plugin teaches others, applied to our own development.
- **Phase 5.5: Draft marketing copy.** New interstitial between Phase 5 (Document) and Phase 6 (Host). Produces a supply-side README (outcomes, not artifacts; Before→After; no `simply`/`comprehensive`/`easily`) and a launch tweet drafted against `reference/marketing-copy.md`'s rubric. Presents via `AskUserQuestion` with four options: *Ship as-is* / *Revise* / *Draft og-card now* / *Skip*. Output: overwrites the Phase 5 template-fill README and writes `MARKETING.md` at the plugin root.
- **`reference/marketing-copy.md`** — load-on-demand drafting rubric. Covers supply-side principles, banned words (`simply` / `easily` / `comprehensive` / `everything you need` / `a suite of`), tagline + launch-tweet structure, and three worked examples (this repo as an exemplar).
- **`templates/plugin/MARKETING.md`** — new scaffold file. Phase 5.5 fills in `## Launch tweet` and `## Alt tweets`. Points to the `og-card` skill instead of an inline TODO.
- **`og-card` sibling skill** at `skills/og-card/`. Interview → typed config at `marketing/og.config.mjs` → rasterize to `assets/og.png` (1200×630) via `@resvg/resvg-js`. Light + dark themes with accent-color glow. First invocation runs a one-time `npm install` in the skill dir (~20s); subsequent renders are ~1s. Users get a GitHub social-preview card without adding deps to their own plugin. Invoked opt-in from Phase 5.5's *Draft og-card now* option or directly via its own description triggers.
- **OG card checks** in `check-submission.sh` — positive `✓` signal when `assets/og.png` is present, warn when `marketing/og.config.mjs` has unreplaced placeholders (partial setup).
- **Supply-side marker + banned-word checks** in `check-submission.sh` — warns (not blocks) when README has no `## Before` / `## What you` / `walk away with` markers, or uses banned marketing words.
- Phase 5.5 line added to `checklists/pre-publish.md`.

### Changed
- SKILL.md Common mistakes table gained a "No CLAUDE.md at the plugin root" row.
- SKILL.md Phase 2 directory diagram now shows `CLAUDE.md` alongside `README.md`, `LICENSE`, `CHANGELOG.md`, `.gitignore`.

## [0.3.0] — 2026-04-16

### Added
- **`--print-cowork-prompt` flag** for `check-submission.sh`. Generates a paste-ready prompt for an interactive Claude Code session (with the built-in `computer-use` MCP server enabled) that drives the entire Cowork install + smoke test on the user's behalf. Pulls a realistic test prompt from the plugin's README Usage section.
- SKILL.md Phase 4b now offers two paths: **Path A (manual)** for any platform, **Path B (semi-automated)** via Claude Code Computer Use on macOS + Pro/Max + v2.1.85+ + interactive session.

### Changed
- ARCHITECTURE.md: Computer Use for Cowork is no longer "future work" — it's available today via Claude Code's built-in `computer-use` MCP server (enable in `/mcp`). The honest gap is that it's interactive-only (no `-p` flag), so the script generates the prompt rather than running it directly.
- `check-submission.sh` Cowork section now describes both paths.

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
