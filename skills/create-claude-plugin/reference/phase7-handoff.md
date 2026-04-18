# Phase 7 handoff protocol

The submission form itself is a human step — Anthropic has no public submission API. But everything **up to** clicking "Submit" should be automated. This file is the exact protocol the executing model follows when the user is ready to submit. Don't improvise; the sequence matters.

## 1. Invoke the pre-flight script (executing model, via Bash tool)

This is both validation *and* the automated handoff. The model runs it — the human does not open a terminal:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-submission.sh "<plugin-path>"
```

On macOS with 0 errors, the script:
- copies a labeled paste-ready block (Examples + all fields, grouped by form page) to the clipboard via `pbcopy`,
- opens `https://claude.ai/settings/plugins/submit` in the browser via `open`.

If errors: fix them and re-run. If warnings: surface them to the user once, then proceed.

## 2. Confirm with `AskUserQuestion`, not free text

Do **not** ask "say go" / "ready?" / any free-text confirmation. Use the Claude Code `AskUserQuestion` tool with a single yes/no.

- **Question:** *"Ready to submit `<plugin-name>` to the official marketplace?"*
- **Options:**
  - `Yes — opening form now` — description: the form tab is open and the clipboard is staged; paste-tab through the fields.
  - `No — I'll do it later` — description: skip for now; re-run `check-submission.sh` whenever you're ready.

Ask once. If the user declines, stop — don't repeat the question later in the session.

## 3. On "Yes", present paste-ready fields grouped by form page

Present the fields using the exact groupings the script already prints (Page 2 / Page 3). Do not re-summarize or reorder. The big paste (Examples) is on the clipboard; the short fields (name, description, repo URL, email, license) should be visible in chat so the user can grab them without re-running the script.

## 4. Platforms field — never claim Claude Cowork

…unless `COWORK_TESTED=yes` was set in the environment before running the script. The script already enforces this; don't override it in your chat output. See `reference/cowork-testing.md` for how to do the Cowork test (manually or via Claude Code Computer Use).

## 5. After submission, stop

Don't prompt, don't poll — Anthropic's review has no public timeline. Phase 7 ends when the user submits.

## Submission tracking: the authoritative source

Anthropic tracks submissions at **https://claude.ai/settings/plugins** (auth-gated). Each entry shows:
- **Status badge** (`Published`, review states, etc.)
- **Submission date**
- **No version column, no sync button** — updates are manual re-submissions, not repo-auto-pulls.

This is where the user checks whether a submission went through. The public file at `anthropics/claude-plugins-official/.claude-plugin/marketplace.json` is a **curated subset** and does *not* reflect every accepted submission — `check-submission.sh` treats absence there as inconclusive.

**To ship an update:** go to the dashboard → click **New submission** → paste the fields from a fresh `check-submission.sh` run → submit. The new version gets reviewed as a separate submission; there is no "edit existing entry" flow and no auto-pull from the tagged GitHub release.

## Form structure (for reference)

The form has three pages:

**Page 1** — Account / submitter info (auto-filled from the Anthropic login).

**Page 2 — Plugin links + details:**
- Plugin link* — your repo URL
- Plugin homepage — optional docs URL (often your README)
- Plugin name* — kebab-case, not taken, no unowned brands
- Plugin description* — one concise sentence about what it does
- Example use cases* — formatted as `Example 1: ... \n Example 2: ...`

**Page 3 — Submission details:**
- Platforms* — surfaces you've tested on (multi-select)
- License type — `MIT`, `Apache-2.0`, etc. (matches your `LICENSE` file)
- Privacy policy URL — only if your plugin collects/transmits user data
- Submitter email* — your contact

Submit at one of:
- **https://claude.ai/settings/plugins/submit**
- **https://platform.claude.com/plugins/submit**

Anthropic reviews for quality + security. No public timeline. Once approved, you'll appear in `/plugin discover` and at https://claude.com/plugins.

For the form fields in detail (and what to do if your plugin name is taken): `reference/submission-form.md`.
