#!/usr/bin/env bash
# Deterministic simulated Phase 7 handoff for the create-claude-plugin hero GIF.
# Driven by docs/demo.tape via `vhs docs/demo.tape`.
# No real API, gh, pbcopy, or browser calls — all output is hardcoded.

set -e

GREEN=$'\033[32m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
YELLOW=$'\033[33m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'
CHECK="${GREEN}✓${RESET}"

phase() {
  printf "%s\n" "${BOLD}${MAGENTA}[Phase 7]${RESET} ${BOLD}$1${RESET}"
}

ok() {
  printf "  %s %s\n" "$CHECK" "$1"
}

label() {
  printf "  ${DIM}%-20s${RESET} %s\n" "$1" "$2"
}

sleep 0.4

phase "Validating plugin…"
sleep 0.7
ok "${DIM}claude plugin validate:${RESET} clean"
sleep 0.6

echo
phase "GitHub repo check…"
sleep 0.7
ok "${DIM}codyhxyz/my-new-plugin:${RESET} live"
sleep 0.6

echo
phase "Cowork smoke test…"
sleep 0.9
ok "install succeeded, test prompt passed"
sleep 0.6

echo
phase "Staging clipboard for submission form…"
sleep 0.9
ok "clipboard staged: ${BOLD}8 fields${RESET} grouped by form page"
sleep 0.7

echo
printf "%s\n" "${DIM}────────────── clipboard preview ──────────────${RESET}"
sleep 0.3

cat <<EOF

${BOLD}${CYAN}=== Page 1: Plugin links ===${RESET}
$(printf "  ${DIM}%-14s${RESET} %s\n" "Name:"     "my-new-plugin")
$(printf "  ${DIM}%-14s${RESET} %s\n" "Tagline:"  "One-line review agent for pull requests.")
$(printf "  ${DIM}%-14s${RESET} %s\n" "Repo URL:" "https://github.com/codyhxyz/my-new-plugin")
$(printf "  ${DIM}%-14s${RESET} %s\n" "Category:" "developer-tools")

${BOLD}${CYAN}=== Page 2: Plugin details ===${RESET}
$(printf "  ${DIM}%-14s${RESET} %s\n" "Description:" "Reviews pull requests against your project's")
$(printf "  ${DIM}%-14s${RESET} %s\n" ""            "conventions, flags risky diffs, and suggests")
$(printf "  ${DIM}%-14s${RESET} %s\n" ""            "concrete fixes before you hit merge.")
$(printf "  ${DIM}%-14s${RESET} %s\n" "Keywords:"   "code-review, pull-request, ci")
$(printf "  ${DIM}%-14s${RESET} %s\n" "Tags:"       "agent, review, github")

${BOLD}${CYAN}=== Page 3: Submission details ===${RESET}
$(printf "  ${DIM}%-14s${RESET} %s\n" "Maintainer:" "plugins@codyh.xyz")
$(printf "  ${DIM}%-14s${RESET} %s\n" "License:"    "MIT")
EOF

sleep 1.2
echo
printf "%s\n" "${DIM}────────────────────────────────────────────────${RESET}"
sleep 0.6

echo
printf "%s\n" "${BOLD}Opening claude.ai/settings/plugins/submit …${RESET}"
sleep 1.0
printf "%s\n" "${DIM}Paste. Tab. Paste. Tab. Done.${RESET}"

sleep 2.5
