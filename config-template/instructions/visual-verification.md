# Visual Verification

For tasks that create or materially change a browser-facing interface, use Playwright while building rather than relying only on source inspection. Start or reuse a reachable local application, verify its behavior through meaningful user interaction, and inspect console and request failures when relevant.

After the changed flow works, call `playwright_browser_take_screenshot` so visual evidence is retained. Capture the state produced by the verified interaction, not merely an initial landing page. Do not pass `filename`; Playwright will generate a safe name under `/workspace/screenshots`. Do not use `page.screenshot()`, shell commands, or other file-only capture paths. This shared directory is outside project checkouts and is ignored by `/workspace/.gitignore`.

OpenCode Web does not currently render image attachments returned by tools. After each capture, extract the generated basename from the screenshot tool result and include a clickable `https://screenshots.<PREVIEW_BASE_DOMAIN>/<url-encoded-basename>` link in the final response, replacing `<PREVIEW_BASE_DOMAIN>` with the configured value. Never claim that a local workspace path is directly viewable by the user.

- A desktop screenshot is required for meaningful browser UI changes.
- Add a mobile screenshot when the change affects responsive layout, navigation, forms, or other viewport-sensitive behavior.
- Take additional screenshots only when distinct states are necessary to demonstrate the work; avoid noisy screenshot dumps.
- Screenshots supplement behavioral assertions and do not replace hydration, interaction, console, network, or automated test checks.
- Never capture secrets, credentials, private environment values, or sensitive user data. Use safe test data and close or obscure sensitive views before capture.
- Do not claim visual verification from HTML, an accessibility snapshot, or an HTTP response alone.
- If the application cannot be run or a screenshot cannot be produced, state the specific blocker in the final response instead of silently omitting visual evidence.

The browser runs outside the application's container. Use a URL reachable from the Playwright browser, such as the published preview URL or the DinD service and reserved port; do not assume an application's loopback `localhost` is reachable.

Persisted browser artifacts are automatically limited to 500 MiB. The user can explicitly remove retained screenshots with `/clear-screenshots`.
