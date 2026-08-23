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

## Deploy

1. Inspect the project and identify its Compose files, production Dockerfile or image, application service, internal HTTP port, startup command, health endpoint, dependencies, and required bootstrap steps. Prefer the production build that actually ships. Treat a development Compose file as a topology reference, not automatically as the preview runtime. Use a dev server only when no viable production target exists or the user explicitly requests it.
2. Inventory prerequisites before building: required `.env` files and secrets, migrations, seed or fixture data, external services, public URLs, API keys, and application-specific bootstrap commands. Do not invent missing secrets. Ensure the resulting data makes at least one representative user journey testable.
3. Reserve the hostname and port:

   ```bash
   preview reserve <slug> "$PWD"
   ```

4. Create a project-local `.opencode/preview.compose.yml` override. Compose appends list values such as `ports`; use Compose tags to replace them explicitly:

   ```yaml
   services:
     web:
       ports: !override
         - "31000:3000"
     database:
       ports: !reset []
   ```

   Replace the example port with the reservation. Apply `ports: !reset []` to every service other than the previewed HTTP service, including databases, caches, APIs, and development servers. Internal service-to-service networking does not require published host ports. YAML language servers may report `!override` and `!reset` as unresolved tags; these are valid Compose tags, and `docker compose config` is authoritative.
5. Put public origins, callback URLs, browser-visible API URLs, and similar hostname-dependent values in the preview Compose override when the base service defines them under `environment:`. Compose `environment:` overrides values from `env_file:`, so changing only `.env` may have no effect. Inspect the resolved values without printing secrets.
6. Validate the fully merged configuration with the exact files and variables that will be used. Check that only one host port is published and that it is the reserved port:

   ```bash
   docker compose -p preview-<slug> -f <compose-file> -f .opencode/preview.compose.yml config
   ```

7. Check DinD capacity before a large build. Do not assume `nproc` represents dedicated CPUs. Constrain framework or build worker counts when the build can fan out aggressively, and avoid starting a build that is likely to exhaust DinD memory.
8. Check bind mounts from the DinD daemon's perspective. Bind source paths resolve on the DinD host, not in the Docker client container. Ensure every runtime container UID can traverse directories and read required files; repository paths owned by UID 1000 with mode `770` will fail for images such as Postgres running as UID 999. Prefer copying immutable scripts into an image or using an appropriately owned volume over broad permission changes.
9. Launch with a stable project name and all required Compose files:

   ```bash
   docker compose -p preview-<slug> -f <compose-file> -f .opencode/preview.compose.yml up -d --build
   ```

10. Inspect `docker compose ps` and relevant logs. Run migrations, seed data, key generation, or other bootstrap commands that were identified earlier. Verify dependency readiness and application behavior directly through `http://dind:<reserved-port>`.
11. Publish the route provisionally after the application responds:

   ```bash
   preview publish <slug>
   ```

12. Get the public URL with `preview url <slug>` and test it with Playwright. HTTP `200`, visible server-rendered HTML, or successful route navigation is not proof of a functioning client application. For a client-rendered application:

    - Fail verification on uncaught JavaScript errors, failed script or chunk requests, hydration errors, or broken runtime WebSockets. Do not dismiss HMR failures as harmless dev noise; use the production build instead when possible.
    - Interact with at least one meaningful control and assert an observable result such as changed DOM or state, navigation, a cookie or session being created, or a successful application request.
    - Exercise a representative path that depends on bootstrapped data or a backend integration when feasible. A storefront, for example, should load usable catalog data rather than only its shell.
    - Framework attachment markers such as React or Vue instance data may support diagnosis, but the definitive check is successful user-visible behavior.

13. If functional verification fails, do not report success. Diagnose and redeploy; if abandoning the attempt, remove the provisional route with `preview remove <slug>`.
14. Report the URL, service name, allocated port, production target, Compose files used, bootstrap performed, interaction tested, and any remaining caveats.

If deployment fails after reservation, diagnose and retry. If abandoning the deployment, run `preview remove <slug>` so the port is released.

## Redeploy

Reuse the existing reservation. Rebuild with the same Compose project name and files, repeat bootstrap as needed, verify `http://dind:<port>`, call `preview publish <slug>`, and repeat functional browser verification. A prior successful interaction does not validate a new build.

## Inspect

Use `preview list` to discover registered previews. Correlate the slug with `docker compose -p preview-<slug> ps`; do not assume a registry entry proves that containers are running.

## Destroy

1. Look up the slug with `preview list` and record its project path and reserved port when present. Independently discover all running and stopped containers with the Compose project label `com.docker.compose.project=preview-<slug>`. The registry and containers are separate sources of truth: continue label-based cleanup if the registry is empty, and do not assume a registry entry means containers exist.
2. Before teardown, record every Docker named volume mounted by those containers, every project-labelled volume, and every bind-mount source containing application data. This is the preservation baseline. Do not proceed without it when project containers exist.
3. Recover the Compose working directory and config files from the containers' `com.docker.compose.project.working_dir` and `com.docker.compose.project.config_files` labels. Prefer stopping the exact project with those recovered files:

   ```bash
   docker compose -p preview-<slug> -f <compose-file> -f .opencode/preview.compose.yml down --remove-orphans
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
   - The public hostname returns status `404` and its response body contains the router marker `No preview is registered for this hostname.`. Status alone is insufficient because a live application may legitimately return `404`.
   - Every recorded named volume and bind-mount source still exists.

7. Leave built images, build cache, generated environment files, the preview Compose override, source files, named volumes, and bind-mounted data in place unless the user explicitly asks to remove them. Report what was removed, what was verified, and which artifacts remain for fast redeployment.
