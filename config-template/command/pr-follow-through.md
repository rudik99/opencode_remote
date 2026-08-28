---
description: Wait for current PR automation and resolve feedback inline until clean
agent: build
---

Follow the current branch's pull request through CI, automated review, and security feedback according to the installed Pull Request Follow-Through instructions. Accept no arguments.

Detect whether this repository has applicable automation before waiting. If it does, loop through checks and feedback, fix actionable issues, validate, commit without amending, push, reply in each originating thread with the fix commit and evidence, resolve completed threads, and repeat against the latest revision. Do not merge. If no applicable automation appears after the registration window, report that and stop. Return a concise final status with links to the PR, checks, and resolved or blocked findings.
