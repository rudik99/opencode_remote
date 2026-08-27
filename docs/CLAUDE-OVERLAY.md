# Claude Code overlay

Adds a Claude Code **Remote Control** agent to the `opencode_remote` stack
without modifying any of its files. `git status` after applying the overlay
shows only untracked files.

```
compose.claude.yaml             services: claude, cloudflared-ssh (profile)
Dockerfile.claude               Claude Code image, mirrors ./Dockerfile
scripts/claude-entrypoint.sh    eligibility checks -> trust -> idle-or-serve
scripts/bootstrap-claude.sh     data/claude/, .env variables
scripts/claude-setup-mcp.sh     user-scope MCP registration (run in container)
docs/CLAUDE-OVERLAY.md          this file
```

## Why this shape

* OpenCode needs an **inbound** tunnel because its web UI must be reachable.
  Claude Code inverts that: `claude remote-control` makes an **outbound**
  connection to `api.anthropic.com` and you drive it from the Claude app.
  No port, hostname, or Access policy is added for the agent itself.
* The container shares `./data/workspace` and `./data/gitconfig` with the
  `opencode` service and runs as the same uid/gid, so both agents see the
  same checkouts.
* Everything Claude needs to survive a rebuild is on `./data/claude/`:
  `config/` = `CLAUDE_CONFIG_DIR` (`.credentials.json`, `.claude.json` with MCP
  registrations and workspace trust) and `azure/` = `AZURE_CONFIG_DIR`
  (`az login` state used by the `mssql-readonly` MCP server).

## Install

```sh
# after scripts/bootstrap.sh
sh scripts/bootstrap-claude.sh
# fill in the '# --- Claude Code overlay' block of .env
docker compose -f compose.yaml -f compose.claude.yaml config >/dev/null
docker compose -f compose.yaml -f compose.claude.yaml up -d --build
```

Tip: `export COMPOSE_FILE=compose.yaml:compose.claude.yaml` in your shell
(or in `.env`) and every `docker compose` command below loses the `-f` flags.

## First sign-in (needs a human, once)

The container starts **waiting** when it has no credentials (code-server is up, so the iPad can reach a terminal), and Remote Control starts by itself within 30 s of a login. `exec` also reaches the
live container:

```sh
docker compose -f compose.yaml -f compose.claude.yaml exec claude claude auth login
#   -> open the printed URL on any device; paste the code back if prompted
docker compose -f compose.yaml -f compose.claude.yaml restart claude
docker compose -f compose.yaml -f compose.claude.yaml logs -f claude
```

`claude auth login` exists from Claude Code 2.1.2xx (verified on 2.1.247). On
an older version run `claude` interactively in the container and use `/login`.

The login has a finite lifetime. Claude Code warns three days before expiry;
run `claude auth login` again before a long unattended period. Once expired,
the container keeps running but every request fails until someone signs in.

## MCP servers

```sh
docker compose -f compose.yaml -f compose.claude.yaml exec claude claude-setup-mcp
```

Registers at **user scope** (so they load in any working directory):

| Server | Transport | Needs |
| --- | --- | --- |
| `context7` | HTTP `https://mcp.context7.com/mcp` | optional `CONTEXT7_API_KEY` |
| `mssql-readonly` | stdio, `/opt/mcp-sqlserver` baked into the image | `SQLSERVER_HOST`, `SQLSERVER_DATABASE` in `.env`, plus `az login --use-device-code` inside the container |
| `erd-docs` | stdio, Python venv | optional: set `ERD_REPO` (git URL of a Python MCP server); cloned under `/workspace`, needs `gh`/`GITHUB_TOKEN` access if private |

`mssql-readonly` uses `SQLSERVER_AUTH_MODE=aad-default`, i.e. the Azure CLI
login of whoever ran `az login` in the container. That identity's database
permissions are the real read-only boundary; the MCP server's SELECT-only
validation and `ApplicationIntent=ReadOnly` are defence in depth only.

## code-server (VS Code in Safari)

The same container runs **code-server** on `:8080` with `--auth none`. Publish it
through the base stack's tunnel as `code.<domain>` -> `http://claude:8080` and put
a Cloudflare Access application (MFA policy) in front — Access *is* the login.
It opens `/workspace`; its terminal is where `claude`, `claude auth login`,
`gh auth login` and `aws sso login --use-device-code` run from the iPad.
Extensions/settings persist on `./data/claude/code-server`; `gh` login on
`./data/claude/gh`. The Claude Code extension (`Anthropic.claude-code`, Open VSX)
is installed at build time if available.

## Operating notes

* **Permission mode**: `CLAUDE_PERMISSION_MODE` (default `default`). Prompts
  are forwarded to the Claude app; `acceptEdits` reduces them.
* **Restarts**: plain server mode is used, not `--continue`, because
  `--continue` exits when its single session ends and would fight
  `restart: unless-stopped`. After a restart the server re-serves the
  sessions it had for about four hours, then a fresh session appears.
* **Network outage**: server mode gives up after ~10 minutes and exits;
  Compose restarts it and it re-registers.
* **Version pin**: set `CLAUDE_CODE_VERSION=<x.y.z>` and rebuild before leaving
  the box unattended. `DISABLE_AUTOUPDATER=1` is set so the image stays at the
  version it was built with.
* **Health**: the healthcheck is code-server's `/healthz`. Remote Control
  state is not part of it — check `docker compose logs claude` or the Claude
  app. A signed-out container is healthy-but-idle so you can reach its
  terminal to sign in.

## Optional SSH tunnel (`--profile ssh-tunnel`)

`cloudflared-ssh` runs a **second** named tunnel from
`CLOUDFLARE_SSH_TUNNEL_TOKEN` and points at `host.docker.internal:22`, i.e. the
host's sshd, so a shell survives the stack being down. Dashboard side: public
hostname `ssh.<domain>` -> `ssh://host.docker.internal:22`, Access application
with an MFA policy. Client side: `cloudflared access ssh --hostname ssh.<domain>`
(Blink on iPadOS: same as a `ProxyCommand`).

Skip the profile if the LAN already has an Access-gated SSH jump host that can
reach the VM; that is strictly less to maintain.

## Open points

1. **Trust seeding** writes `projects["/workspace"].hasTrustDialogAccepted`
   into `.claude.json`. If a future Claude Code version changes that layout,
   run `claude` once interactively in `/workspace` instead and remove the
   seeding block.
