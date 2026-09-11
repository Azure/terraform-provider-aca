---
title: Sandbox Code Interpreter
description: Experimental Python MCP workload on ACA Sandboxes
breadcrumbs:
  - title: Home
    url: /
  - title: Examples
    url: /examples/
---

# Sandbox Code Interpreter

The `examples/sandbox_code_interpreter` configuration builds a digest-pinned
Python image in ACR, creates a rich-preview Sandbox Group, and uses
`experimental/sandbox_workload` to create or reuse a Sandbox.

Terraform destroy intentionally preserves all Sandbox data-plane resources.
Cleanup is always an explicit user action.
