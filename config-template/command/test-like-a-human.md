---
description: Exercise a browser workflow as a user and return fresh acceptance evidence
agent: build
---

Test the browser workflow described in `$ARGUMENTS` against the latest runnable isolated preview. Require a non-empty workflow description. Do not use production unless the user explicitly requires a production smoke test, and do not make source changes unless the user asks for fixes after the test.

Follow the installed Browser Verification Gate. Start from a normal user entry point, navigate through visible controls, complete the described journey with safe test data, assert the final visible state, inspect console errors, inspect relevant network requests, test desktop and mobile when applicable, and retain screenshots of meaningful final states.

Only completed tool calls count as evidence. If an action fails, remains running, times out, or the latest implementation is not reachable, report `FAIL` or `BLOCKED`; never infer success. Return the required `Browser verification` evidence block and concise reproduction details for every failure.
