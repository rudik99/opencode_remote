---
description: Build, run, verify, and publish a project through the wildcard preview domain.
agent: build
---

Deploy a Docker preview for the current project. Load and follow the `preview-deployment` skill exactly.

User arguments: `$ARGUMENTS`

Infer the service, internal port, and slug when they are unambiguous. Ask one concise question if a required choice is ambiguous. Use the secure per-preview file returned by `preview env <slug>` and reuse the same ordered Compose `--env-file` arguments throughout the lifecycle without displaying resolved secrets. Obtain the public URL with `preview url <slug>`. Carry the deployment through production build, bootstrap, local health verification, provisional route publication, and functional public browser verification. Never report success based only on HTTP responses or rendered HTML; prove hydration with an observable interaction. Do not stop after merely proposing commands.
