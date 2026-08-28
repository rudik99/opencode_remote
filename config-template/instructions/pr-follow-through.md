# Pull Request Follow-Through

When the user asks to commit and create or update a pull request, opening or pushing the PR is not completion when that repository has active CI, automated review, or security agents. Follow the PR through the applicable automation before handing it back. Never merge a pull request. Merging is always reserved for the human user, even when all checks pass.

After every PR creation or push, inspect the current PR, checks, reviews, top-level comments, and inline review threads with `gh`. Allow a short registration window by polling for up to two minutes so newly triggered checks and bots can appear. Treat automation as active when the PR exposes check runs or status contexts, required checks, bot-authored reviews or comments, or requested app/bot reviewers. Do not wait indefinitely merely because workflow files exist, and do not wait for human approval unless the user requests it. If no applicable automation appears during discovery, report that fact and finish normally.

When applicable automation exists, loop until all of these are true:

1. Every required or relevant automated check is in a successful, skipped, or otherwise non-blocking terminal state.
2. Every actionable CI failure, automated review finding, security finding, and unresolved inline thread is either fixed or answered with a technically justified non-fix.
3. The latest pushed commit, not an earlier revision, is the revision covered by the final checks and review pass.

For each loop iteration:

1. Wait for active checks to finish. If a polling command times out, resume polling; never treat a timeout or missing result as success. If external automation is stuck beyond its normal timeout or unavailable, report `BLOCKED` with its public URL and status.
2. Gather failed-check logs and all new top-level and inline feedback. Deduplicate findings and distinguish actionable issues from informational output.
3. Fix actionable issues in the working tree, run focused validation, create a new commit without amending prior commits, and push it.
4. Reply directly in each originating inline review thread after its fix is pushed. Use the form `Resolved in <commit>: <specific fix>. Validation: <specific evidence>.` Then resolve that thread through the GitHub GraphQL API. Do not resolve a thread before its fix and validation are pushed. If thread resolution is unavailable, leave the inline reply and report that limitation.
5. For a justified non-fix, reply in the same thread with the concrete rationale and evidence before resolving it. Ask the user instead of resolving when the feedback is ambiguous or represents a product decision.
6. After every push, restart discovery and waiting because new CI runs or agent feedback can supersede earlier results.

For top-level findings that have no review thread, reply to the originating PR comment when GitHub supports replies; otherwise add a PR comment that quotes or links the specific finding and records its resolution. Keep each response tied to one finding so the user can see exactly what changed.

Before final handoff, refresh checks, comments, reviews, and unresolved threads one last time. Report the final commit, check results, each resolved finding with its thread or comment link when available, and any remaining `BLOCKED` item. Never claim the PR is clean while checks are pending, feedback is unresolved, or the latest push has not completed its automation pass.
