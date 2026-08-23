# OpenCode Remote

A self-hosted OpenCode workspace with persistent projects and sessions, Docker-in-Docker application previews, browser automation, GitHub HTTPS authentication, and wildcard Cloudflare Tunnel routing.

Each project can be built inside the isolated DinD daemon and published at a stable hostname such as `shop.example.com`. OpenCode receives explicit deployment and teardown procedures that verify real browser behavior and preserve application data.

## Architecture

```text
Browser
  -> Cloudflare Access and Tunnel
  -> OpenCode web UI

Project preview hostname
  -> wildcard Cloudflare Tunnel route
  -> Caddy preview router
  -> port published by an application inside DinD
```

The host does not publish OpenCode, preview, browser, or Docker daemon ports. Cloudflared reaches services over the private Compose network.

## Included

- OpenCode web UI running as a non-root user
- Persistent projects, configuration, sessions, and preview registry
- Docker 29 DinD daemon with Docker Compose and Buildx in OpenCode
- Caddy wildcard preview router with dynamic, persistent routes
- Browserless Chromium and Playwright MCP
- Context7 and GitHub MCP templates
- GitHub CLI HTTPS credential helper
- `/preview-deploy` and `/preview-destroy` commands
- Hardened preview instructions covering production builds, Compose overrides, bootstrap, hydration checks, data preservation, and orphan cleanup
- Common development tools including Git, Git LFS, GitHub CLI, Node 22, Python 3, `nano`, `rg`, `fd`, and a compiler toolchain

## Requirements

- Linux host with Docker Engine and Docker Compose, or Docker Desktop
- A model provider supported by OpenCode
- A Cloudflare account, domain, and named tunnel for remote access
- At least 12 GB of available memory with the default limits
- GitHub token if private repository access or GitHub MCP is required

DinD requires `privileged: true`. Read the security section before exposing this stack.

## Quick Start

1. Clone and bootstrap the repository:

   ```bash
   git clone https://github.com/rudik99/opencode_remote.git
   cd opencode_remote
   ./scripts/bootstrap.sh
   ```

2. Edit `.env`:

   ```bash
   nano .env
   ```

3. Set at least:

   ```dotenv
   OPENCODE_SERVER_PASSWORD=a-long-random-password
   OPENCODE_MODEL=anthropic/claude-sonnet-4-6
   ANTHROPIC_API_KEY=your-provider-key
   PREVIEW_BASE_DOMAIN=example.com
   CLOUDFLARE_TUNNEL_TOKEN=your-named-tunnel-token
   ```

4. On Linux, set `OPENCODE_UID` and `OPENCODE_GID` to the values printed by `bootstrap.sh`. This keeps bind-mounted files writable.

5. Build and start the stack:

   ```bash
   docker compose up -d --build
   docker compose ps
   ```

6. Confirm the local service health:

   ```bash
   docker compose exec opencode sh -c \
     'curl -fsS -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" http://127.0.0.1:4096/global/health'
   ```

The variables in the final command are container environment variables. Run it exactly through `docker compose exec` as shown.

## Cloudflare Setup

Create or reuse a remotely managed named tunnel. Add two public hostnames to the same tunnel:

| Public hostname | Service |
| --- | --- |
| `code.your-domain.com` | `http://opencode:4096` |
| `*.your-preview-domain.com` | `http://preview-router:80` |

Set `PREVIEW_BASE_DOMAIN=your-preview-domain.com` in `.env`.

Cloudflare Universal SSL normally covers the apex and one wildcard label. With `PREVIEW_BASE_DOMAIN=example.com`, `project.example.com` is covered. A hostname such as `project.preview.example.com` may require an additional certificate because it is two labels below the apex.

If the tunnel dashboard says **No DNS records changed**, add the wildcard DNS record manually in the preview domain's zone:

```text
Type:    CNAME
Name:    *
Target:  <tunnel-uuid>.cfargotunnel.com
Proxy:   Proxied
TTL:     Auto
```

Verify it with a random hostname:

```bash
curl -I https://dns-probe.your-preview-domain.com
```

An unregistered hostname should return `404` with:

```text
No preview is registered for this hostname.
```

## Model Providers

The template defaults to Anthropic. Change `OPENCODE_MODEL` and add the corresponding provider credential to `compose.yaml` and `.env` when using another provider. OpenCode model IDs include the provider prefix.

The live OpenCode configuration is initialized at:

```text
./data/config/opencode.jsonc
```

The versioned template is at:

```text
./config-template/opencode.jsonc
```

Restart OpenCode after changing configuration, commands, agents, or skills:

```bash
docker compose restart opencode
```

## GitHub Access

Put a GitHub token in `.env`:

```dotenv
GITHUB_TOKEN=github-token
```

A classic token needs `repo` for private repositories. Add `read:org` when organization or team API queries are required. Prefer a fine-grained token restricted to the repositories this environment needs.

Recreate OpenCode after changing `.env`:

```bash
docker compose up -d --no-deps --force-recreate opencode
```

Verify authentication without printing the token:

```bash
docker compose exec opencode gh api user --jq .login
```

Configure commit attribution in the persistent Git config:

```bash
docker compose exec opencode git config --global user.name "Your Name"
docker compose exec opencode git config --global user.email "your-github-email"
```

Use an account-specific GitHub noreply address if the account has no public email.

## Projects

Clone or create projects under `/workspace` in OpenCode. On the host they are stored under:

```text
./data/workspace
```

The same absolute `/workspace` path is mounted into OpenCode and DinD. This is important because bind-mount source paths are resolved by the DinD daemon, not the Docker client.

## Preview Lifecycle

From an OpenCode session opened in a project, run:

```text
/preview-deploy my-project
```

The deployment procedure:

1. Prefers the project's production image over a development server.
2. Reserves a port from `31000-31999`.
3. Generates or updates a preview Compose override.
4. Removes unrelated host port publishing with Compose `!reset` and `!override` tags.
5. Builds, migrates, seeds, and starts the application in DinD.
6. Publishes `<slug>.<PREVIEW_BASE_DOMAIN>` through Caddy.
7. Uses Playwright to prove that the application hydrated and a meaningful interaction works.

HTTP `200` and server-rendered HTML are deliberately not considered sufficient proof of success.

To stop a preview while preserving data and build artifacts:

```text
/preview-destroy my-project
```

Destroy removes project containers, its Compose network, the Caddy route, and the port reservation. It preserves named volumes, bind-mounted data, source files, images, build cache, generated environment files, and the preview override. The procedure records volumes before teardown and verifies they still exist afterward.

Useful low-level commands:

```bash
docker compose exec opencode preview list
docker compose exec opencode preview url my-project
```

## Persistence And Backups

Back up these host paths:

```text
./data/workspace    Project repositories and bind-mounted application data
./data/config       OpenCode configuration, skills, commands, and agents
./data/state        OpenCode sessions and state
./data/previews     Preview registry
./data/gitconfig    Git identity and credential-helper configuration
```

The Compose volume ending in `_dind-data` contains DinD images, build cache, and application named volumes. Back it up if named-volume application data must survive total stack loss. Do not assume backing up `./data` includes it.

The Caddy configuration volumes can be recreated from the preview registry by republishing previews.

## Updates

Update outer images and rebuild OpenCode:

```bash
docker compose pull
docker compose build --pull opencode
docker compose up -d
```

Pin `OPENCODE_VERSION` and image tags for reproducible or production-oriented installations. Review release notes before major Docker, Caddy, Browserless, or OpenCode upgrades.

## Security

- Put Cloudflare Access with MFA in front of both OpenCode and wildcard preview hostnames.
- Use a long OpenCode server password as defense in depth.
- Never publish or tunnel DinD port `2375`; it is an unauthenticated privileged Docker API on the private Compose network.
- DinD itself is privileged. Anyone who can execute unrestricted commands in OpenCode can control its nested containers and data.
- Use repository-scoped GitHub credentials and rotate tokens after accidental disclosure.
- Keep `.env` and `data/` out of Git. They are ignored by this repository.
- Do not put production secrets in project Compose files or preview overrides.
- Retain resource limits. A build can otherwise consume the entire host even when `nproc` reports more CPUs than DinD was allocated.
- Protect backups because they may contain source code, sessions, credentials, and application data.

## Troubleshooting

### Tunnel connects but preview DNS does not resolve

Confirm the wildcard CNAME exists and is proxied. The tunnel ingress rule and DNS record are separate configuration objects.

### Unknown preview returns an application response

Check that the wildcard tunnel service is exactly `http://preview-router:80`, not the OpenCode service or a DinD port.

### Preview returns 200 but controls do not work

Use the production image, inspect JavaScript and chunk failures, and verify hydration with an observable interaction. Development HMR failures can leave server-rendered HTML visible while the client runtime is inert.

### Compose override publishes duplicate ports

Compose appends lists. Use `ports: !override` on the previewed service and `ports: !reset []` on every other service. Some YAML language servers flag these tags incorrectly; `docker compose config` is authoritative.

### Bind mount permission denied inside DinD

The runtime container UID needs read and directory-traverse permission on the host path as seen by DinD. Prefer copying immutable initialization files into an image or using a correctly owned volume instead of making repository contents world-writable.

### OpenCode cannot clone a private repository

Verify `gh api user`, inspect `git config --global --show-origin --list`, and use an HTTPS clone URL. Ensure the token can access the repository and organization.

### Build runs out of memory

Limit framework build workers rather than relying on `nproc`, increase `DIND_MEMORY_LIMIT` only when the host has capacity, and inspect DinD disk/cache usage before retrying.

### Docker cannot create the Compose network

If Docker reports that address pools are exhausted or the configured subnet overlaps another network, choose an unused private `/24` in `.env`:

```dotenv
OPENCODE_NETWORK_SUBNET=10.77.78.0/24
```

Inspect current allocations with `docker network inspect $(docker network ls -q)` before selecting a replacement.

### Reset generated configuration

Stop the stack, back up `data/config`, and copy the desired files from `config-template`. Bootstrap intentionally does not overwrite an existing live configuration.

## Repository Layout

```text
compose.yaml                    Outer service stack
Dockerfile                      OpenCode development image
config-template/                Initial OpenCode configuration and instructions
preview/Caddyfile               Initial wildcard router configuration
preview/preview                 Preview registry and Caddy lifecycle helper
scripts/bootstrap.sh            Safe first-run data initialization
data/                           Runtime state; generated and ignored
```

## License

Licensed under the [MIT License](LICENSE).
