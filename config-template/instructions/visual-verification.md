# Browser Verification Gate

For every task that creates or materially changes a browser-facing interface or user workflow, test the final implementation in Playwright before handing work back to the user. Source inspection, builds, typechecks, unit tests, HTML, accessibility snapshots, and HTTP responses do not replace this browser gate.

Use an isolated local or published preview that is reachable from the Playwright browser. Do not use production as the primary test environment or deploy to production merely to verify a change. The browser runs outside the application's container, so do not assume application loopback `localhost` is reachable.

The verification must occur after the final relevant code change, rebuild, restart, or preview update. Any subsequent change to the tested behavior invalidates earlier browser evidence and requires the affected journey to be tested again. Evidence from an earlier implementation does not count.

Before claiming completion or recommending deployment:

1. Start at a normal user entry point and perform the changed journey through visible links, buttons, labels, and form controls. Do not deep-link past behavior that the task changed.
2. Require every relevant Playwright action to finish successfully. A `running`, failed, timed-out, stale, or truncated tool result is not evidence of success.
3. Assert the resulting visible state and persistence that matter to the task, including refresh or back navigation when relevant.
4. Inspect browser console errors after the final interaction. Success requires zero unexplained errors; identify and justify any known unrelated errors.
5. Inspect the relevant network request when the workflow reads or writes data. Confirm the expected endpoint, parameters or payload, and successful status after the final interaction.
6. Test a desktop viewport. Also test a mobile viewport when navigation, forms, dialogs, responsive layout, or touch-sized controls are affected.
7. Call `playwright_browser_take_screenshot` after the verified interaction. Capture meaningful final states, not only a landing page. Do not pass `filename`; Playwright will write safely under `/workspace/screenshots`.

Screenshots supplement behavioral assertions; they never replace interaction, console, network, hydration, or automated test checks. Never capture secrets, credentials, private environment values, or sensitive user data. Use safe test data and avoid irreversible actions.

The final response for a browser-facing change must include a concise `Browser verification` block with the tested URL, journey, relevant network result, console result, viewports, screenshot links, and `PASS`, `FAIL`, or `BLOCKED`. Do not say the work is verified when any required action is incomplete. If the preview cannot run or the gate cannot pass, state the blocker and hand the work back as incomplete.

OpenCode Web does not render image attachments returned by tools. Convert each generated screenshot basename into a clickable `https://screenshots.<PREVIEW_BASE_DOMAIN>/<url-encoded-basename>` link, replacing `<PREVIEW_BASE_DOMAIN>` with the configured value. Never claim that a local workspace path is directly viewable by the user. Persisted browser artifacts are limited to 500 MiB and can be removed with `/clear-screenshots`.
