# Contributing to PLUGIN_NAME

Thanks for taking the time to improve this plugin. This doc covers the dev loop, the checks we expect to pass before merge, and how releases get cut.

## Local dev loop

```bash
git clone https://github.com/YOUR_GH_USER/PLUGIN_NAME
cd PLUGIN_NAME
claude --plugin-dir .
```

Inside the session:

- `/help` — your plugin's skills should appear under the `PLUGIN_NAME:` namespace
- `/agents` — agents the plugin ships should be listed
- `/reload-plugins` — reload after edits (no restart needed)

## Before you open a PR

1. `claude plugin validate .` — must pass
2. `scripts/check-submission.sh .` (from the create-claude-plugin repo) — 0 errors
3. Update `README.md` or `CHANGELOG.md` if user-visible behavior changed
4. Bump `version` in `.claude-plugin/plugin.json` only when cutting a release

## Releases

1. Bump `version` in `.claude-plugin/plugin.json` (semver: patch = fix, minor = feature, major = breaking).
2. Add a dated entry at the top of `CHANGELOG.md` (`date +%Y-%m-%d`).
3. Commit, then run `scripts/publish-to-github.sh` (from `create-claude-plugin`) — it'll tag, push, cut a GitHub release, and refresh the entry in `codyhxyz/claude-plugins`.

## Reporting bugs

Use the **Bug report** issue template. Include plugin version (`/plugin list`) and `claude --version`.
