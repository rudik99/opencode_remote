---
description: Remove retained Playwright screenshots without touching source code or other workspace data
agent: build
---

Clear screenshot artifacts from exactly `/workspace/screenshots`.

Refuse to proceed if `/workspace` or `/workspace/screenshots` is a symlink. Resolve the target with `realpath` and require the result to be exactly `/workspace/screenshots`. Before deletion, count the regular screenshot files and their total size. Delete only regular files beneath that directory with `.png`, `.jpg`, `.jpeg`, or `.webp` extensions, do not follow symlinks, and remove empty child directories afterward. Preserve `/workspace/screenshots` itself and all files outside it. Report the number of files and bytes removed.
