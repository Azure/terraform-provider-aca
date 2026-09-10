---
title: ACA Express
description: Express environment and container app through dedicated AzAPI resources
breadcrumbs:
  - title: Home
    url: /
  - title: Examples
    url: /examples/
---

# ACA Express

The `examples/express_mode` configuration creates an Express environment and
app using `Microsoft.App/managedEnvironments@2026-03-02-preview` and
`Microsoft.App/containerApps@2026-03-02-preview`.

It demonstrates HTTP ingress, scaling, probes, CORS, IP restrictions,
and ephemeral storage. Unsupported Express features, including all volumes and
volume mounts, are rejected by module preconditions.
