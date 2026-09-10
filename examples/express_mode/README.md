# ACA Express

Creates an Azure Container Apps Express environment and an Express container
app through the root module. Express resources use the currently registered
`Microsoft.App/*@2026-03-02-preview` ARM contract through dedicated AzAPI resources;
standard environments and apps continue to use AzureRM.

The app demonstrates the currently supported Express subset:

- single revision and HTTP ingress;
- scale to zero plus an HTTP scale rule;
- HTTP health probe;
- CORS and IP restrictions;
- custom ephemeral storage.

Express does not support sidecars, init containers, Dapr, jobs, TCP ingress,
insecure HTTP, additional ports, Key Vault secret references, system-assigned
identity, volumes or volume mounts, multiple revisions, sticky sessions,
premium ingress, workload profiles, or zone redundancy. The module rejects
these combinations at plan time.

The compatibility flag remains available for existing callers:

```hcl
environment = {
  feature_flags = {
    express_mode = true
  }
}
```

New configurations should use the explicit mode:

```hcl
environment = {
  environment_mode = "Express"
}
```

## Deploy

```powershell
terraform init
terraform apply
```

The example defaults to `swedencentral` and resource group `tf-aca-17`.
