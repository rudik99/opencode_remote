# Visual Verification

For tasks that create or materially change a browser-facing interface, use Playwright while building rather than relying only on source inspection. Start or reuse a reachable local application, verify its behavior through meaningful user interaction, and inspect console and request failures when relevant.

After the changed flow works, call Playwright's screenshot tool so visual evidence appears inline in chat. Capture the state produced by the verified interaction, not merely an initial landing page. Use a concise project-and-state filename that is a single basename without `/`, `\\`, or `..`; screenshots are persisted under `/workspace/.opencode-artifacts/screenshots`.

- A desktop screenshot is required for meaningful browser UI changes.
- Add a mobile screenshot when the change affects responsive layout, navigation, forms, or other viewport-sensitive behavior.
- Take additional screenshots only when distinct states are necessary to demonstrate the work; avoid noisy screenshot dumps.
- Screenshots supplement behavioral assertions and do not replace hydration, interaction, console, network, or automated test checks.
- Never capture secrets, credentials, private environment values, or sensitive user data. Use safe test data and close or obscure sensitive views before capture.
- Do not claim visual verification from HTML, an accessibility snapshot, or an HTTP response alone.
- If the application cannot be run or a screenshot cannot be produced, state the specific blocker in the final response instead of silently omitting visual evidence.

The browser runs outside the application's container. Use a URL reachable from the Playwright browser, such as the published preview URL or the DinD service and reserved port; do not assume an application's loopback `localhost` is reachable.

Persisted browser artifacts are automatically limited to 500 MiB. The user can explicitly remove retained screenshots with `/clear-screenshots`.
