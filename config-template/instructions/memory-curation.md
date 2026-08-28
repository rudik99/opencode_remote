# Durable Memory Curation

For the primary agent only: before the final response to a substantial implementation, debugging, deployment, migration, or configuration task, decide whether the work revealed durable project knowledge that future agents would otherwise need to rediscover.

When it did, delegate once to the `memory-curator` subagent. Pass a concise factual summary of the lasting decisions, commands, invariants, conventions, operational procedures, and confirmed pitfalls discovered during the task, plus the project root. Wait for it to finish before responding to the user.

Do not invoke the curator for informational questions, planning-only work, trivial edits, temporary operational state, facts already documented in `AGENTS.md`, or a task whose purpose is memory curation. Never delegate secrets or credential values. The `memory-curator` must remain the only agent editing memory during that delegation.

Memory curation is part of completing the task, not a separate user-facing ceremony. Mention an `AGENTS.md` update in the final response only when one was actually made.
