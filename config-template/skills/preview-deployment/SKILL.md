---
name: preview-deployment
description: Docker preview deployment through DinD, a wildcard domain, and the preview helper. Use when asked to run, expose, publish, redeploy, inspect, or tear down a project preview.
---

# Preview Deployment

Use the `preview` helper and the Docker daemon at `DOCKER_HOST`. Cloudflare is configured once for `PREVIEW_BASE_DOMAIN`; never create per-project Cloudflare DNS or tunnel records.

## Invariants

- Preview hostnames are `<slug>.<PREVIEW_BASE_DOMAIN>`.
- Use lowercase DNS-safe slugs. Prefer the repository or project directory name.
- The `preview` helper owns host ports `31000-31999`; do not select a port manually.
- Applications must listen on `0.0.0.0` inside their container.
- A DinD-published port is reachable from the router as `http://dind:<port>`.
- Never expose Docker port `2375` through the router or Cloudflare.
- Never run `docker compose down -v` or remove application data unless the user explicitly asks.
- Only the previewed HTTP service may publish a host port, and it must use the reserved port. Reset host port publishing on every other service.
- Do not report success from HTTP status or rendered HTML alone. A browser-facing client application must demonstrably hydrate and respond to user interaction.
- Each preview has one persistent environment file at `/workspace/.preview-env/<slug>.env`. Never print its values, include them directly in commands, or commit the file.

## Deploy

1. Inspect the project and identify its Compose files, production Dockerfile or image, application service, internal HTTP port, startup command, health endpoint, dependencies, and required bootstrap steps. Prefer the production build that actually ships. Treat a development Compose file as a topology reference, not automatically as the preview runtime. Use a dev server only when no viable production target exists or the user explicitly requests it.
2. Inventory prerequisites before building: required `.env` files and secrets, migrations, seed or fixture data, external services, public URLs, API keys, and application-specific bootstrap commands. Do not invent missing secrets. Ensure the resulting data makes at least one representative user journey testable.
3. Reserve the hostname and port:

   ```bash
   preview reserve <slug> "$PWD"
   ```

4. Initialize the preview's persistent environment file and record the returned path:

   ```bash
   preview_env=$(preview env <slug>)
   ```

   The helper requests directory mode `700` and file mode `600`, and always removes all group/other access. NFSv4 ACL datasets may retain an owner execute bit and display the file as `700`; this is acceptable only when the ACL remains owner-only. Store one `KEY=VALUE` per line. For secret values, ask the user to edit the file with `nano "$preview_env"`; do not request that secrets be pasted into chat or place them in shell command arguments. A project may commit an `.env.preview.example` containing key names and safe examples only.
5. Construct one ordered set of Compose environment arguments and reuse it for validation, build, bootstrap, redeploy, and teardown. If the project has a base `.env`, load it first and the preview file last so preview values win:

   ```text
   --env-file .env --env-file /workspace/.preview-env/<slug>.env
   ```

   Omit the project `.env` argument when it does not exist. `--env-file` supplies Compose interpolation; it does not automatically inject every value into a container.
6. Create a project-local `.opencode/preview.compose.yml` override. Compose appends list values such as `ports`; use Compose tags to replace them explicitly:

   ```yaml
   services:
      web:
        ports: !override
          - "31000:3000"
        environment:
          DATABASE_URL: ${DATABASE_URL:?required}
          PUBLIC_APP_URL: ${PUBLIC_APP_URL:?required}
        build:
          args:
            NEXT_PUBLIC_API_URL: ${NEXT_PUBLIC_API_URL:?required}
      database:
        ports: !reset []
   ```

   Replace the example port with the reservation. Apply `ports: !reset []` to every service other than the previewed HTTP service, including databases, caches, APIs, and development servers. Internal service-to-service networking does not require published host ports. YAML language servers may report `!override` and `!reset` as unresolved tags; these are valid Compose tags, and `docker compose config` is authoritative.
7. Explicitly allowlist each required runtime variable under the target service's `environment:`. Put public origins, callback URLs, browser-visible API URLs, and similar hostname-dependent values in the preview override. Compose service `environment:` overrides both `env_file:` and image values, so changing only an env file cannot replace a value hard-coded by the base Compose file. Use build arguments only for non-secret values that must be embedded into a frontend build. Use BuildKit or Compose secrets for sensitive build inputs; Docker build arguments can persist in image metadata or layers.
8. Validate the fully merged configuration with the exact environment arguments, files, and variables that will be used. Never print raw resolved configuration because it contains secrets:

   ```bash
   docker compose <env-args> -p preview-<slug> -f <compose-file> -f .opencode/preview.compose.yml config --quiet
   ```

   To audit published ports, pipe JSON directly to a narrow `jq` projection that returns service names and ports only. Do not display service environments.
9. Check DinD capacity before a large build. Do not assume `nproc` represents dedicated CPUs. Constrain framework or build worker counts when the build can fan out aggressively, and avoid starting a build that is likely to exhaust DinD memory.
10. Check bind mounts from the DinD daemon's perspective. Bind source paths resolve on the DinD host, not in the Docker client container. Ensure every runtime container UID can traverse directories and read required files; repository paths owned by UID 1000 with mode `770` will fail for images such as Postgres running as UID 999. Prefer copying immutable scripts into an image or using an appropriately owned volume over broad permission changes.
11. Launch with a stable project name, the same environment arguments, and all required Compose files:

   ```bash
   docker compose <env-args> -p preview-<slug> -f <compose-file> -f .opencode/preview.compose.yml up -d --build
   ```

12. Inspect `docker compose ps` and relevant logs. Run migrations, seed data, key generation, or other bootstrap commands with the same environment arguments. Verify dependency readiness and application behavior directly through `http://dind:<reserved-port>`. Do not print full container environments or resolved Compose configuration while diagnosing.
13. Publish the route provisionally after the application responds:

   ```bash
   preview publish <slug>
   ```

14. Get the public URL with `preview url <slug>` and test that URL with Playwright. HTTP `200`, visible server-rendered HTML, or successful route navigation is not proof of a functioning client application. For a client-rendered application:

    - Fail verification on uncaught JavaScript errors, failed script or chunk requests, hydration errors, or broken runtime WebSockets. Do not dismiss HMR failures as harmless dev noise; use the production build instead when possible.
    - Interact with at least one meaningful control and assert an observable result such as changed DOM or state, navigation, a cookie or session being created, or a successful application request.
    - Exercise a representative path that depends on bootstrapped data or a backend integration when feasible. A storefront, for example, should load usable catalog data rather than only its shell.
    - Framework attachment markers such as React or Vue instance data may support diagnosis, but the definitive check is successful user-visible behavior.

15. If functional verification fails, do not report success. Diagnose and redeploy; if abandoning the attempt, remove the provisional route with `preview remove <slug>`.
16. Report the URL returned by `preview url <slug>`, service name, allocated port, environment-file path without its contents, production target, Compose files used, bootstrap performed, interaction tested, and any remaining caveats.

If deployment fails after reservation, diagnose and retry. If abandoning the deployment, run `preview remove <slug>` so the port is released.

## Redeploy

Reuse the existing reservation and `/workspace/.preview-env/<slug>.env`. Rebuild with the same ordered environment arguments, Compose project name, and files; repeat bootstrap as needed, verify `http://dind:<port>`, call `preview publish <slug>`, obtain the public URL with `preview url <slug>`, and repeat functional browser verification. A prior successful interaction does not validate a new build.

## Inspect

Use `preview list` to discover registered previews. Correlate the slug with `docker compose -p preview-<slug> ps`; do not assume a registry entry proves that containers are running.

## Destroy

1. Look up the slug with `preview list` and record its project path and reserved port when present. Record the public URL with `preview url <slug>` while the registry entry exists. Independently discover all running and stopped containers with the Compose project label `com.docker.compose.project=preview-<slug>`. The registry and containers are separate sources of truth: continue label-based cleanup if the registry is empty, and do not assume a registry entry means containers exist.
2. Before teardown, record every Docker named volume mounted by those containers, every project-labelled volume, and every bind-mount source containing application data. This is the preservation baseline. Do not proceed without it when project containers exist.
3. Recover the Compose working directory and config files from the containers' `com.docker.compose.project.working_dir` and `com.docker.compose.project.config_files` labels. Reconstruct the same environment arguments, using the project `.env` first when present and `/workspace/.preview-env/<slug>.env` last when present. Prefer stopping the exact project with those recovered files:

   ```bash
   docker compose <env-args> -p preview-<slug> -f <compose-file> -f .opencode/preview.compose.yml down --remove-orphans
   ```

   If the original files cannot be recovered or no longer exist, remove all containers and networks selected by the exact `com.docker.compose.project=preview-<slug>` label. Never select resources by a partial name match.
4. Never pass `-v`, run `docker volume rm`, or run a volume prune. Confirm every named volume in the preservation baseline still exists after container teardown, and confirm recorded bind-mount sources still exist. A missing data volume is a teardown failure and must be reported explicitly.
5. Remove the route and release its registry reservation, even when the registry was already empty:

   ```bash
   preview remove <slug>
   ```

6. Verify all teardown outcomes rather than inferring them from commands:

   - No running or stopped container remains with the exact Compose project label.
   - The previously reserved `http://dind:<port>` no longer accepts connections when a port was recorded.
   - The previously recorded public URL returns status `404` and its response body contains the router marker `No preview is registered for this hostname.`. Status alone is insufficient because a live application may legitimately return `404`.
   - Every recorded named volume and bind-mount source still exists.

7. Leave built images, build cache, `/workspace/.preview-env/<slug>.env`, other generated environment files, the preview Compose override, source files, named volumes, and bind-mounted data in place unless the user explicitly asks to remove them. Verify the preview environment file has no group/other permissions when it exists; do not require exact mode `600` on an NFSv4 ACL dataset that preserves an owner-only execute bit. Report what was removed, what was verified, and which artifacts remain for fast redeployment.
