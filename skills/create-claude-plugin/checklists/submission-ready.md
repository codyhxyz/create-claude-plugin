# Submission-ready checklist

Run before opening https://claude.ai/settings/plugins/submit.

The form has no draft-save. If you can't fill in any of these without thinking, fix it first — don't half-fill the form.

## Pre-flight script

- [ ] `./scripts/check-submission.sh /path/to/your/plugin` passes
- [ ] Output copied for paste into the form

## Page 2 — Plugin links + details

- [ ] **Plugin link** — repo URL is public and live
- [ ] **Plugin homepage** — optional, but if you set one it loads
- [ ] **Plugin name** — checked against `claude-plugins-official` and not taken:
  ```bash
  curl -s https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json \
    | jq -r '.plugins[].name' | grep -x YOUR_PLUGIN_NAME && echo "TAKEN" || echo "available"
  ```
- [ ] **Plugin name** — does not use unowned brand names
- [ ] **Plugin description** — one sentence, leads with the verb, no hype words
- [ ] **Example use cases** — at least two, each:
  - [ ] Includes a realistic user prompt (not a description of one)
  - [ ] Names a tool, file type, or scenario concretely

## Page 3 — Submission details

- [ ] **Platforms** — only checked surfaces I've actually tested:
  - [ ] **Claude Code** — `claude --plugin-dir ./` + `claude plugin validate .` both pass; tried each skill / agent in a session
  - [ ] **Claude Cowork** — installed via Claude desktop app → Cowork → Customize → Browse plugins (or .zip upload); smoke-tested in a real Cowork session. If not done, **leave Cowork unchecked.**
- [ ] **License type** — matches my `LICENSE` file (`MIT`, `Apache-2.0`, etc.)
- [ ] **Privacy policy URL** — if my plugin sends user data anywhere external, this is filled. Otherwise N/A.
- [ ] **Submitter email** — current and monitored

## Quality bar (Anthropic reviews for this)

- [ ] Plugin actually works (not just compiles — does the thing it claims)
- [ ] README has install instructions, usage, and at least 1–2 concrete examples
- [ ] No security smells: no `eval`-style execution of untrusted input, no MCP servers calling arbitrary URLs without justification, no hooks that exfiltrate data
- [ ] No broken links in README
- [ ] CHANGELOG present and accurate

## Last steps

- [ ] One more `claude plugin validate .` for good measure
- [ ] Final commit pushed; no uncommitted changes locally
- [ ] Released a tag matching `version`: `git tag v0.1.0 && git push --tags` (optional but recommended)
