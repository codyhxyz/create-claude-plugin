# VHS tape for PLUGIN_NAME's hero GIF.
#
# Render with:
#   ${CLAUDE_PLUGIN_ROOT}/scripts/record-demo.sh
# or directly:
#   vhs docs/demo.tape
#
# Output is written to docs/hero.gif — the path the README template points at.
#
# Design notes:
#   - Keep total runtime under ~20s. Longer GIFs balloon the repo.
#   - Drive the demo from a companion script (e.g. docs/demo-session.sh) so
#     the timing is deterministic and repeats cleanly on re-record.

Output docs/hero.gif

Set Theme "Dracula"
Set FontSize 13
Set Width 1100
Set Height 820
Set Padding 30
Set TypingSpeed 25ms

Hide
Type "clear"
Enter
Show
Sleep 400ms

# PLUGIN_NAME author — replace the block below with your deterministic demo.
# Common shape: run a pre-made shell script that prints a scripted session
# (user prompt → agent response) with ANSI colors and small sleeps baked in.
#
# Example:
#   Type "bash docs/demo-session.sh"
#   Sleep 300ms
#   Enter
#   Sleep 15s

Type "echo 'Replace this demo tape with your plugin's real session.'"
Sleep 300ms
Enter
Sleep 3s
