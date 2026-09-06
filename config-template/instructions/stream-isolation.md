# Concurrent Stream Isolation

Sessions using the exact same checkout share its filesystem watcher, TypeScript LSP, and ESLint server. Prefer the primary checkout by default for lower memory use and faster project warmup. Worktrees intentionally trade those shared resources for filesystem and branch isolation.

- Do not create a worktree automatically merely because a request changes code. Create one only when the user explicitly requests an isolated or concurrent stream, when overlapping implementation would make a shared checkout unsafe, or when unrelated in-progress changes prevent safe work in the current checkout.
- In a shared checkout, inspect `git status --short` before editing, preserve unrelated changes, and avoid running concurrent commands that mutate the same files, dependencies, build outputs, databases, ports, or Compose resources.
- When isolation is required, create the worktree before reading project source or installing dependencies with `stream create <lowercase-task-name> <repository>`.
- Continue the implementation exclusively from the returned worktree path. Set every shell command's working directory to that path and scope every read, glob, grep, edit, task, test, and build to it. Do not use relative paths that resolve against the primary checkout and do not inspect equivalent source files there.
- A session's OpenCode project directory cannot be changed after creation. For the cleanest isolation and lowest watcher/LSP overhead, open the returned worktree as a new OpenCode project. If continuing in the current session, treat the returned path as the effective project root for all tools and report it to the user.
- Reuse the same worktree for the lifetime of the stream. Do not create another worktree for follow-up work on the same task.
- Before editing or testing, check `git rev-parse --show-toplevel` and `git status --short`. If another active stream owns that checkout or unrelated in-progress changes are present, stop and move the work to a dedicated worktree; never reset or clean another stream's work.
- Run tests, builds, dependency installation, generated-code commands, and development servers only from the stream worktree. Keep stream-local artifacts inside that worktree.
- Give Docker Compose resources a stream-specific project name. For previews, always use the value returned by `preview slug`; use it consistently for the preview slug and `docker compose -p preview-<slug>`. Never reuse a preview slug registered to another project path.
- For non-preview test stacks, derive a unique Compose project name from the repository and worktree names. Do not publish fixed host ports unless the test requires host access; prefer container networking, ephemeral ports, or the preview reservation.
- Do not stop, rebuild, remove, or inspect by partial name any container, network, volume, dev server, or browser session owned by another stream. Select Compose resources by their exact project label.
- Keep test data isolated per stream. Do not point concurrent tests at the same mutable database/schema, Redis namespace, queue, storage directory, or `.env` file.
- `stream remove <name> <repository>` refuses to remove a dirty worktree. Commit or deliberately preserve work before cleanup; do not force removal.
