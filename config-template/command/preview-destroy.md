---
description: Stop a project preview and remove its wildcard route without deleting data volumes.
agent: build
---

Destroy the requested Docker preview. Load and follow the `preview-deployment` skill exactly, especially its destroy procedure, label-based fallback, and prohibition on deleting volumes. Reuse the standard preview environment file when Compose interpolation requires it, but never delete or display it. Record the public URL with `preview url <slug>` before removing the route. Record the data-volume baseline and verify it survived; prove route removal by matching the router's response body rather than status alone.

Preview slug or user arguments: `$ARGUMENTS`

If no slug is supplied and it cannot be inferred from the current project, use `preview list` and ask one concise question. Verify both the Compose teardown and route removal.
