---
title: Native Sandbox with Public Image
description: First-class Terraform management of an ACA Sandbox using Ubuntu
breadcrumbs:
  - title: Home
    url: /
  - title: Examples
    url: /examples/
---

# Native Sandbox with Public Image

The `examples/sandbox_native_public` configuration creates the Sandbox Group
control plane and then uses the native `Azure/aca` provider to discover the
public Ubuntu disk image and manage an individual data-plane Sandbox.

The example has no ACA CLI or PowerShell dependency. Its deployed resources are
protected from Terraform destroy until the protection is explicitly removed.
