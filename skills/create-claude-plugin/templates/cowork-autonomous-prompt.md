# Autonomous Cowork smoke-test prompt

Fed into a headless `claude -p` subprocess by `scripts/cowork-smoke-test.sh`.
Placeholders `{{PLUGIN_NAME}}`, `{{PLUGIN_PATH}}`, `{{TEST_PROMPT}}` are
filled in by the shell script before invocation. The subprocess has
`@github/computer-use-mcp` available and runs without a human in the loop.

---

You are running an autonomous Cowork smoke-test for the plugin **{{PLUGIN_NAME}}**.
**No human is in this loop.** Never ask for confirmation. Every step is yours to execute.

## Preconditions (guaranteed by the caller)

- macOS with Claude desktop app installed
- `@github/computer-use-mcp` is loaded (tools available under `mcp__computer-use__*`)
- Claude.app already has Accessibility + Screen Recording permissions (or this script wouldn't have been dispatched)

## Your job

1. **Open Claude desktop.** Call `mcp__computer-use__open_application` with `"Claude"`. Screenshot.
2. **Navigate to Cowork.** Locate and click the Cowork tab. Screenshot.
3. **Install the plugin.**
   - Click Customize → Browse plugins.
   - If `{{PLUGIN_NAME}}` appears in the marketplace list, click Install.
   - If NOT found, zip the plugin directory via Bash: `(cd "{{PLUGIN_PATH}}/.." && zip -qr /tmp/{{PLUGIN_NAME}}.zip "$(basename "{{PLUGIN_PATH}}")" -x "*/node_modules/*" "*/.git/*")` then drag the zip into the UI via `mcp__computer-use__drag_and_drop`.
   - Confirm `{{PLUGIN_NAME}}` is installed (listed in the installed plugins view).
4. **Start a new Cowork session.** Click new-session button. Screenshot.
5. **Run the test prompt.** Type or paste this *exact* prompt into the session:
   ```
   {{TEST_PROMPT}}
   ```
6. **Wait 60 seconds.** Let Claude respond.
7. **Evaluate the response.** PASS if Claude invokes `{{PLUGIN_NAME}}`'s primary skill or agent (mentions the skill name, starts the documented workflow, or loads the SKILL.md). FAIL otherwise.

## Output contract

Your response MUST end with exactly one of these lines (no trailing punctuation):

- `COWORK_TEST_RESULT: PASS`
- `COWORK_TEST_RESULT: FAIL — <one-line reason>`

The caller greps for this marker. Anything before it is debug output for humans to read; anything after is ignored.

## Failure modes — don't loop

If a step fails twice (click target missing, app crashes, test prompt never gets a response), stop and emit:

```
COWORK_TEST_RESULT: FAIL — <which step, what went wrong>
```

Don't retry a third time. Don't ask the user. Fail-and-report is better than hanging.

## Timing budget

- Total wall-clock target: under 3 minutes
- Each `mcp__computer-use__*` call: under 15 seconds
- Post-prompt wait: 60 seconds max
- If the run approaches 3 minutes without a PASS marker, emit FAIL with reason "timeout" and exit.
