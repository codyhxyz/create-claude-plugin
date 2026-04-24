#!/usr/bin/env bash
# publish-to-github.sh — idempotent GitHub repo create + edit for a Claude plugin
#
# Usage:  ./publish-to-github.sh <plugin-dir> [--owner <gh-owner>] [--private]
#
# Reads <plugin-dir>/.claude-plugin/plugin.json for name, description,
# homepage, and version. Auto-detects topics:
#   - baseline: claude-code, claude-code-plugin, claude-plugin
#   - component-type: claude-skill (skills/), claude-agent (agents/),
#                     claude-hook (hooks/), mcp (.mcp.json)
#   - manifest keywords[]
#
# Idempotent: if the repo already exists on GitHub for the current auth'd user
# (or the provided --owner), this skips `gh repo create` and proceeds straight
# to `gh repo edit`. In all cases, `gh repo edit` is run to sync description,
# homepage, and topics.
#
# After metadata sync, if plugin.json version doesn't match an existing tag:
# tag v<version>, push, cut a GitHub release from the matching CHANGELOG entry.
#
# Finally, open (or update) a PR against the meta-marketplace registry
# (default: codyhxyz/codyhxyz-plugins) adding this plugin's entry.
#
# NOTE: this script only handles the *first-time* registry entry. There is
# no ongoing sync — marketplace.json tracks identity (name, repo, description,
# keywords), not activity. /plugin install reads each plugin's own repo at
# install time, and GitHub already exposes last-push time on the repo page.
#
# Env:
#   CCP_REGISTRY_REPO   override registry (default: codyhxyz/codyhxyz-plugins)
#   CCP_SKIP_REGISTRY=1 skip the registry PR step
#   CCP_SKIP_RELEASE=1  skip tagging + gh release
#
# Prereqs: gh (authenticated), jq, git.

set -euo pipefail

PLUGIN_DIR=""
OWNER=""
VISIBILITY="--public"

usage() {
  echo "Usage: $0 <plugin-dir> [--owner <gh-owner>] [--private]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)   OWNER="${2:-}"; shift 2 ;;
    --private) VISIBILITY="--private"; shift ;;
    --public)  VISIBILITY="--public"; shift ;;
    --help|-h) usage ;;
    *)         [[ -z "$PLUGIN_DIR" ]] && PLUGIN_DIR="$1"; shift ;;
  esac
done

[[ -z "$PLUGIN_DIR" ]] && usage
[[ ! -d "$PLUGIN_DIR" ]] && { echo "ERROR: '$PLUGIN_DIR' is not a directory" >&2; exit 2; }

command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 2; }

MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }

NAME=$(jq -r '.name // empty' "$MANIFEST")
DESCRIPTION=$(jq -r '.description // empty' "$MANIFEST")
HOMEPAGE=$(jq -r '.homepage // empty' "$MANIFEST")
VERSION=$(jq -r '.version // empty' "$MANIFEST")

[[ -z "$NAME" ]]        && { echo "ERROR: plugin.json missing 'name'" >&2; exit 1; }
[[ -z "$DESCRIPTION" ]] && { echo "ERROR: plugin.json missing 'description'" >&2; exit 1; }
[[ -z "$VERSION" ]]     && { echo "ERROR: plugin.json missing 'version'" >&2; exit 1; }

# Resolve owner: --owner flag wins, else the authed gh user
if [[ -z "$OWNER" ]]; then
  OWNER=$(gh api user --jq .login 2>/dev/null || true)
  [[ -z "$OWNER" ]] && { echo "ERROR: gh not authenticated (run 'gh auth login')" >&2; exit 1; }
fi
SLUG="$OWNER/$NAME"

# ---------- Auto-detect topics ----------
TOPICS=(claude-code claude-code-plugin claude-plugin)
# `agent-skills` is the cross-agent convention used by anthropics/skills and
# indexed by skills.sh — add it whenever skills/ is present so the repo shows
# up via `npx skills add <owner>/<repo>` and gets crawled by the directory.
if [[ -d "$PLUGIN_DIR/skills" ]]; then
  TOPICS+=(claude-skill agent-skills)
fi
[[ -d "$PLUGIN_DIR/agents" ]] && TOPICS+=(claude-agent)
[[ -d "$PLUGIN_DIR/hooks"  ]] && TOPICS+=(claude-hook)
[[ -f "$PLUGIN_DIR/.mcp.json" ]] && TOPICS+=(mcp)

# Add manifest keywords (filter to gh topic rules: lowercase alnum + hyphens, <=50 chars)
while IFS= read -r kw; do
  [[ -z "$kw" ]] && continue
  kw_norm=$(echo "$kw" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/^-*//;s/-*$//' | cut -c1-50)
  [[ -z "$kw_norm" ]] && continue
  TOPICS+=("$kw_norm")
done < <(jq -r '.keywords[]? // empty' "$MANIFEST")

# Dedupe topics
UNIQ_TOPICS=()
for t in "${TOPICS[@]}"; do
  skip=""
  for u in "${UNIQ_TOPICS[@]:-}"; do [[ "$u" == "$t" ]] && skip=1 && break; done
  [[ -z "$skip" ]] && UNIQ_TOPICS+=("$t")
done

# ---------- Ensure a git repo + initial commit ----------
if [[ ! -d "$PLUGIN_DIR/.git" ]]; then
  echo "==> Initializing git repo in $PLUGIN_DIR"
  (cd "$PLUGIN_DIR" && git init -q && git add -A && git commit -q -m "Initial commit" || true)
fi

# ---------- Create repo (idempotent) ----------
if gh repo view "$SLUG" >/dev/null 2>&1; then
  echo "==> Repo $SLUG already exists on GitHub — skipping create"
else
  echo "==> Creating $SLUG on GitHub"
  (cd "$PLUGIN_DIR" && gh repo create "$SLUG" $VISIBILITY \
    --source=. --remote=origin --push \
    --description "$DESCRIPTION")
fi

# ---------- Always edit (idempotent sync of description/homepage/topics) ----------
echo "==> Syncing repo metadata on $SLUG"
EDIT_ARGS=(--description "$DESCRIPTION")
[[ -n "$HOMEPAGE" ]] && EDIT_ARGS+=(--homepage "$HOMEPAGE")
for t in "${UNIQ_TOPICS[@]}"; do EDIT_ARGS+=(--add-topic "$t"); done
gh repo edit "$SLUG" "${EDIT_ARGS[@]}"

echo "==> Repo metadata synced: https://github.com/$SLUG"
echo "    Topics: ${UNIQ_TOPICS[*]}"

# ---------- skills.sh install hint ----------
# skills.sh is a cross-agent skills directory that auto-indexes public GitHub
# repos containing SKILL.md files. There is no explicit publish API — a repo
# appears once skills.sh's crawler picks it up (typically within a few days).
# If this plugin exposes skills, print the install command so the author can
# share it and so downstream agents (Cursor, Codex, Gemini, etc.) can consume.
if [[ -d "$PLUGIN_DIR/skills" ]]; then
  echo ""
  echo "==> skills.sh install command (cross-agent):"
  echo "      npx skills add $SLUG"
  echo "    Directory listing (appears after crawl): https://skills.sh/$SLUG"
  # Sanity check: warn if a scaffold template with placeholder 'SKILL_NAME'
  # would leak into `npx skills add --full-depth` output. Templates should
  # carry `metadata.internal: true` so they stay hidden from discovery.
  LEAKS=$(grep -rl '^name: SKILL_NAME' "$PLUGIN_DIR/skills" 2>/dev/null \
    | xargs -I{} sh -c 'grep -q "internal: true" "{}" || echo "{}"' 2>/dev/null || true)
  if [[ -n "$LEAKS" ]]; then
    echo "    WARN: template SKILL.md files without 'metadata.internal: true' detected:" >&2
    echo "$LEAKS" | sed 's/^/      /' >&2
    echo "    These will surface as broken 'SKILL_NAME' entries on skills.sh." >&2
  fi
fi

# ---------- Tag + release ----------
if [[ "${CCP_SKIP_RELEASE:-}" == "1" ]]; then
  echo "==> CCP_SKIP_RELEASE=1 — skipping tag + release"
else
  TAG="v$VERSION"
  if (cd "$PLUGIN_DIR" && git rev-parse --verify "refs/tags/$TAG" >/dev/null 2>&1); then
    echo "==> Tag $TAG already exists locally — skipping"
  else
    # Pull the matching CHANGELOG block if present. Tolerates both
    # "## [0.1.0] — YYYY-MM-DD" and "## 0.1.0" heading styles.
    NOTES=""
    if [[ -f "$PLUGIN_DIR/CHANGELOG.md" ]]; then
      NOTES=$(awk -v ver="$VERSION" '
        BEGIN { grab=0 }
        $0 ~ "^## +\\[?" ver "\\]?" { grab=1; next }
        grab && /^## / { exit }
        grab { print }
      ' "$PLUGIN_DIR/CHANGELOG.md" | sed -e '/^[[:space:]]*$/d')
    fi
    [[ -z "$NOTES" ]] && NOTES="Release $TAG"

    (cd "$PLUGIN_DIR" && git tag -a "$TAG" -m "$TAG" && git push origin "$TAG")

    if gh release view "$TAG" --repo "$SLUG" >/dev/null 2>&1; then
      echo "==> Release $TAG already exists on $SLUG — skipping gh release create"
    else
      gh release create "$TAG" --repo "$SLUG" --title "$TAG" --notes "$NOTES"
      echo "==> Cut release $TAG on $SLUG"
    fi
  fi
fi

# ---------- Meta-marketplace auto-PR ----------
REGISTRY_REPO="${CCP_REGISTRY_REPO:-codyhxyz/codyhxyz-plugins}"

if [[ "${CCP_SKIP_REGISTRY:-}" == "1" ]]; then
  echo "==> CCP_SKIP_REGISTRY=1 — skipping registry PR"
  exit 0
fi
if [[ "$SLUG" == "$REGISTRY_REPO" ]]; then
  echo "==> This IS the registry repo — skipping self-PR"
  exit 0
fi

echo "==> Updating $REGISTRY_REPO with entry for $NAME"
REG_TMP=$(mktemp -d -t ccp-registry.XXXXXX)
trap 'rm -rf "$REG_TMP"' EXIT

if ! gh repo clone "$REGISTRY_REPO" "$REG_TMP" -- --depth 1 --quiet >/dev/null 2>&1; then
  echo "    could not clone $REGISTRY_REPO — skipping registry PR (set CCP_SKIP_REGISTRY=1 to silence)" >&2
  exit 0
fi

REG_MANIFEST="$REG_TMP/.claude-plugin/marketplace.json"
if [[ ! -f "$REG_MANIFEST" ]]; then
  echo "    $REGISTRY_REPO has no .claude-plugin/marketplace.json — skipping" >&2
  exit 0
fi

# Entry we want in the registry. Keywords come straight from plugin.json.
ENTRY=$(jq -n \
  --arg name        "$NAME" \
  --arg description "$DESCRIPTION" \
  --arg homepage    "$HOMEPAGE" \
  --arg repo        "$SLUG" \
  --slurpfile kw    <(jq '[.keywords[]? // empty]' "$MANIFEST") \
  '{
    name: $name,
    source: {source:"github", repo:$repo},
    description: $description,
    homepage: (if $homepage == "" then null else $homepage end),
    repository: ("https://github.com/" + $repo),
    keywords: ($kw[0] // [])
  } | with_entries(select(.value != null))')

EXISTING=$(jq --arg n "$NAME" '.plugins[] | select(.name == $n)' "$REG_MANIFEST")
if [[ -n "$EXISTING" ]] && diff <(echo "$EXISTING" | jq -S .) <(echo "$ENTRY" | jq -S .) >/dev/null 2>&1; then
  echo "==> Registry entry already up to date — no PR needed"
  exit 0
fi

# Upsert the entry.
TMP_MANIFEST=$(mktemp)
if [[ -n "$EXISTING" ]]; then
  jq --arg n "$NAME" --argjson entry "$ENTRY" \
    '.plugins = [.plugins[] | if .name == $n then $entry else . end]' \
    "$REG_MANIFEST" > "$TMP_MANIFEST"
  COMMIT_MSG="Update $NAME entry to v$VERSION"
else
  jq --argjson entry "$ENTRY" '.plugins += [$entry]' "$REG_MANIFEST" > "$TMP_MANIFEST"
  COMMIT_MSG="Add $NAME to marketplace"
fi
mv "$TMP_MANIFEST" "$REG_MANIFEST"

BRANCH="add-${NAME}-v${VERSION}"
(
  cd "$REG_TMP"
  git checkout -b "$BRANCH" >/dev/null 2>&1
  git add .claude-plugin/marketplace.json
  git commit -m "$COMMIT_MSG" >/dev/null
  git push -u origin "$BRANCH" >/dev/null 2>&1

  # If a PR for this branch already exists, skip creation.
  if gh pr view --repo "$REGISTRY_REPO" "$BRANCH" >/dev/null 2>&1; then
    echo "==> PR for $BRANCH already open on $REGISTRY_REPO — updated via push"
  else
    gh pr create \
      --repo "$REGISTRY_REPO" \
      --title "$COMMIT_MSG" \
      --body "Adds/updates \`$NAME\` (v$VERSION) in the marketplace registry.

- Source: \`github:$SLUG\`
- Description: $DESCRIPTION
- Homepage: ${HOMEPAGE:-n/a}

Opened by \`create-claude-plugin/scripts/publish-to-github.sh\`."
  fi
)
echo "==> Registry PR opened/updated on $REGISTRY_REPO"
