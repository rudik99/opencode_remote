# Proportional Execution

Match investigation and validation effort to the task's actual risk. Prefer the smallest correct change and the shortest reliable path to evidence. Do not turn a simple task into a broad audit, production deployment exercise, or repeated full build.

Classify work before choosing validation:

- Documentation, comments, and metadata: inspect the diff and run only relevant formatting or syntax checks. Do not build, deploy, open a browser, or launch subagents.
- Isolated logic or backend changes: run focused tests and the narrowest relevant typecheck. Do not build a production image unless packaging is affected.
- Browser-visible changes: run focused checks, start the cheapest representative isolated runtime, and perform one conclusive pre-handoff browser journey under the Browser Verification Gate.
- Dependency patches, production packaging, or preview infrastructure: validate patches and static artifacts cheaply before one final production build and one preview update.
- Security, migrations, concurrency, payments, pagination, or large-data behavior: add specialized tests and perform focused correctness, security, or performance review before expensive builds.

Validate from cheapest to most expensive: inspect the active code path, edit, run syntax and diff checks, run focused tests, review high-risk behavior, run a targeted build, update one isolated preview if required, then perform the final browser gate. A failure at an early stage must not trigger an expensive later stage.

Default to one successful final production build and one preview update. Retry an expensive step only after a concrete failure and a relevant change. After two failures using the same expensive strategy, stop and choose a different approach. Never use full Docker builds to check patch syntax, lockfile hashes, formatting, or a focused unit test.

Do not start databases, Redis, queues, Compose stacks, migrations, or unrelated services for lockfile generation, formatting, source generation, or static patch checks. Reuse an existing builder image or run a focused tool directly when isolation is needed.

Review architecture, performance, and security before the final build when a change removes pagination, scans large tables, retrieves heavy relations, changes authentication, patches vendored dependencies, or alters deployment infrastructure. Use no subagent for simple tasks and at most one focused review subagent by default for complex tasks. Keep memory curation, broad reviews, and documentation polishing off the critical path.

For browser-visible work, diagnostic browser runs may help development but only one fresh final journey is required for handoff. Combine navigation, interaction, visible assertions, console inspection, relevant network inspection, and one meaningful screenshot into a focused scenario. Test mobile only when responsive behavior, navigation, forms, dialogs, or touch targets changed.

Search local exact-version source first. After identifying the active implementation, stop exploring alternatives unless evidence remains ambiguous. Default to one discovery pass and one confirmation pass before explaining why broader research is necessary.

Keep substantial work durable before long-running builds or ending a turn. Do not leave the only copy in a temporary worktree. Do not duplicate equivalent validation across branches when the behavior and dependency base are unchanged.

If an operation runs longer than three minutes, tell the user what is still running and why. Stop it if it unexpectedly starts unrelated infrastructure. Do not silently retry slow commands. Stop when the acceptance criteria and risk-appropriate evidence are satisfied; do not expand scope without a concrete finding.
