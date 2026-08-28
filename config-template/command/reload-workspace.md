---
description: Reload current workspace config and MCP servers without restarting OpenCode
agent: build
---

Reload the current workspace through the local OpenCode API. This invalidates only the current workspace instance so changes to `opencode.json`, commands, agents, and MCP credentials are read again. Do not restart OpenCode, containers, or other workspaces.

Use `curl` with HTTP basic authentication from `OPENCODE_SERVER_USERNAME` and `OPENCODE_SERVER_PASSWORD`. Pass the current `$PWD` as the URL-encoded `directory` query parameter to every request. Never print credentials, resolved config, response headers, or use shell tracing.

First call `POST http://127.0.0.1:4096/instance/dispose` and require HTTP 200 with the response `true`. Then call `GET http://127.0.0.1:4096/mcp` for the same directory to initialize the workspace again. Report the MCP names and statuses only. If any server failed, include only its public error message.
