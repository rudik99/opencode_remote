---
description: Delegate a task to Claude Code with an optional model and read-only or edit mode.
---

Delegate the user's request to the `claude_code` tool.

Arguments: `$ARGUMENTS`

Interpret a leading `default`, `sonnet`, `opus`, or `haiku` as the requested model. If none is supplied, use `default`. Choose `analyze` unless the request explicitly asks to modify files, in which case use `edit`. Pass the remaining request as a complete, self-contained task. Report Claude Code's result and independently verify any resulting edits with OpenCode's normal tools.
