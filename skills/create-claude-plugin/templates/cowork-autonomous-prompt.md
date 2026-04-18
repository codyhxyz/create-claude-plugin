# Autonomous Cowork smoke-test prompt

Fed into a headless `claude -p` subprocess by `scripts/cowork-smoke-test.sh`.
Placeholders `{{PLUGIN_NAME}}`, `{{PLUGIN_PATH}}`, `{{TEST_PROMPT}}` are
filled in by the shell script before invocation. The subprocess has
`@github/computer-use-mcp` available (as `mcp__gh-computer-use__*`) and
runs without a human in the loop.

---

You are running an autonomous Cowork smoke-test for the plugin **{{PLUGIN_NAME}}**.
**No human is in this loop.** Never ask for confirmation. Every step is yours to execute.

## How the gh-computer-use MCP works (critical — read carefully)

Applications are referenced by **runtime IDs** of the shape `app.macos.<hex>` returned from `list_applications`. The friendly name `"Claude"` is NOT a valid application identifier — passing it anywhere will fail with `Unknown application id`.

The correct sequence to drive any app is:

1. `open_application` — launches an app by path (e.g. `/Applications/Claude.app`) or name. Idempotent: if already running, it foregrounds it.
2. `list_applications` — returns currently running apps with their IDs and window lists. Find the entry whose `displayName` matches the target app.
3. Extract that entry's `id` field (e.g. `app.macos.abcdef1234`). **Use this ID** for every subsequent call that takes an application — `request_access`, `get_application_details`, window manipulation, etc.

## Your job

1. **Launch Claude desktop.** Call `open_application` with `{"path": "/Applications/Claude.app"}`. Wait 2 seconds for it to foreground.
2. **Discover its runtime ID.** Call `list_applications`. Scan the returned `applications` array for an entry where `displayName` is `Claude` (exact match). Save its `id` as `$CLAUDE_ID`. If no match, emit `COWORK_TEST_RESULT: FAIL — Claude.app not visible after open_application (check /Applications/Claude.app exists)` and exit.
3. **Request access** (may be a no-op if TCC already granted it to the parent process chain — don't fail on this step alone). Call `request_access` with `{"applications": ["$CLAUDE_ID"]}`. If declined, continue anyway and let a later screenshot/click be the real test.
4. **Navigate to Cowork.** Use `screenshot` to see Claude.app's current state, then `click` the Cowork tab by its screen coordinates. If the Cowork tab isn't visible, log what tabs you see and emit `COWORK_TEST_RESULT: FAIL — Cowork tab not found in Claude.app (is this the right build?)`.
5. **Install the plugin** at path `{{PLUGIN_PATH}}`:
   - Click Customize → Browse plugins.
   - If `{{PLUGIN_NAME}}` appears in the marketplace list, click Install.
   - If NOT found: zip the plugin via Bash — `(cd "{{PLUGIN_PATH}}/.." && zip -qr /tmp/{{PLUGIN_NAME}}.zip "$(basename "{{PLUGIN_PATH}}")" -x "*/node_modules/*" "*/.git/*")` — then `drag_and_drop` the zip onto the plugins upload area.
   - Confirm `{{PLUGIN_NAME}}` is installed (screenshot → visible in installed plugins list).
6. **Start a new Cowork session.** Click the new-session button. Screenshot.
7. **Run the test prompt.** Use `type_text` to enter this exact string:
   ```
   {{TEST_PROMPT}}
   ```
   Press Enter.
8. **Wait 60 seconds.** Let Claude respond. Screenshot the response.
9. **Evaluate the response.** PASS if Claude invokes `{{PLUGIN_NAME}}`'s primary skill or agent (mentions the skill name in its response, starts the documented workflow, or loads the SKILL.md). FAIL otherwise.

## Output contract

Your response MUST end with exactly one of these lines (no trailing punctuation):

- `COWORK_TEST_RESULT: PASS`
- `COWORK_TEST_RESULT: FAIL — <one-line reason>`

The caller greps for this marker. Anything before it is debug output; anything after is ignored.

## Failure modes — don't loop

If a step fails twice (app can't be found, click target missing, test prompt never gets a response), stop and emit:

```
COWORK_TEST_RESULT: FAIL — <which step, what went wrong>
```

Don't retry a third time. Don't ask the user. Fail-and-report beats hanging.

## Timing budget

- Total wall-clock target: under 3 minutes
- Each `mcp__gh-computer-use__*` call: under 15 seconds
- Post-prompt wait: 60 seconds max
- If the run approaches 3 minutes without a PASS marker, emit FAIL with reason "timeout" and exit.
