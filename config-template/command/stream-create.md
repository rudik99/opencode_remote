---
description: Create an isolated Git worktree for a concurrent implementation stream.
agent: build
---

Create an isolated stream for the current repository with `stream create <name> "$PWD"`, where the requested lowercase stream name is `$ARGUMENTS`. Do not read or change project source in the original checkout. Report the returned worktree path and use it as the working directory for all subsequent tools. Recommend opening that directory as a new OpenCode project for complete project, watcher, and LSP isolation.
