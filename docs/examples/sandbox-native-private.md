---
title: Native Sandbox with Private Image
description: First-class Terraform management of ACA disk images and Sandboxes
breadcrumbs:
  - title: Home
    url: /
  - title: Examples
    url: /examples/
---

# Native Sandbox with Private Image

The `examples/sandbox_native_private` configuration imports Azure Linux into
ACR through ARM, creates a repository-scoped read-only registry token, and uses
the native `Azure/aca` provider to manage both a private Sandbox disk image and
its Sandbox.

The path is Terraform-native: it does not require ACA CLI, PowerShell, a Docker
daemon, or a local image-build provisioner. The credential is passed through
the provider's write-only registry token argument.
