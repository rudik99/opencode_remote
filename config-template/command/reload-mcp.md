---
description: Disconnect and reconnect one configured MCP server without restarting OpenCode
agent: build
---

Reload the MCP server named in `$ARGUMENTS` through the local OpenCode API.

Require exactly one non-empty MCP name matching `^[A-Za-z0-9._-]+$`. Refuse extra arguments, `all`, path separators, shell syntax, or any name not present in the keys returned by `GET http://127.0.0.1:4096/mcp` for the current `$PWD` directory. Never print credentials or use shell tracing.

Use `curl` with HTTP basic authentication from `OPENCODE_SERVER_USERNAME` and `OPENCODE_SERVER_PASSWORD`. Pass the current `$PWD` as the URL-encoded `directory` query parameter. First call `POST /mcp/{name}/disconnect`, then call `POST /mcp/{name}/connect`. Require HTTP 200 from both calls. Finally query `GET /mcp` and report only that MCP server's resulting status. Do not restart the OpenCode process, containers, or unrelated MCP servers.
