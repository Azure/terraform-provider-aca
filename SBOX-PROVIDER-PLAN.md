# Native ACA Sandbox Data-Plane Provider Plan

Status: Initial v1 implementation added under `provider/`; live public and private image deployments validated
Date: September 10, 2026
Target repository: `Azure/terraform-provider-aca`
Proposed provider source: `registry.terraform.io/Azure/aca`

## 1. Executive decision

Build a native Terraform provider in a new `provider/` subdirectory of this
repository. The provider will be written in Go with Terraform Plugin Framework
and will call the ACA Sandbox regional data-plane REST API directly.

The official `azure-containerapps-sandbox` Python SDK is the API and behavioral
reference, not a runtime dependency. The provider must not shell out to Python,
PowerShell, Azure CLI, ACA CLI, or any other executable.

The first release will be intentionally narrow:

- Data-plane operations only. SandboxGroup ARM resources and role assignments
  remain managed by AzureRM/AzAPI and the existing Terraform modules.
- Managed resources:
  - `aca_sandbox_disk_image`
  - `aca_sandbox`
- Read-only data sources:
  - `aca_sandbox_disk_image`
  - `aca_sandbox`
  - `aca_sandbox_public_disk_image`
- Delete remote objects by default.
- Support an explicit resource-level retention option for handing a preserved
  object out of Terraform state without deleting it.
- Exclude shell execution, file transfer, directory operations, and other
  imperative SDK methods from the provider.
- Defer snapshots, volumes, and secrets to later releases.

The provisional minimum Terraform CLI version is Terraform 1.11 so registry
tokens and sensitive environment values can use write-only resource arguments
instead of being persisted in plans or state. Phase 0 must verify the exact
Plugin Framework negotiation behavior with older Terraform and OpenTofu
versions before this becomes a release requirement.

The existing modules can retain their current Terraform compatibility floor.
Any root configuration that uses the new provider's write-only attributes would
inherit the provider's higher CLI requirement.

## 2. Why a provider is required

The existing `experimental/sandbox_workload` module proves the service flow,
but it is not an acceptable long-term Terraform integration:

- `terraform init` cannot install ACA CLI or PowerShell dependencies.
- HCP Terraform and customer runners may not contain either executable.
- `local-exec` and `data.external` do not implement native Terraform CRUD,
  import, refresh, timeout, diagnostics, or drift semantics.
- CLI output is preview-quality and has already changed shape.
- Process arguments and child-process environments create avoidable credential
  exposure risks.
- Retrying a command after an output parsing failure can duplicate resources.
- Terraform cannot accurately distinguish a remote resource from the imperative
  script invocation that happened to create it.

A native provider solves these issues by shipping a single Terraform plugin
binary with a typed schema, direct authentication, direct HTTP requests, native
state, deterministic polling, and explicit lifecycle behavior.

## 3. Confirmed design choices

The following choices were made during planning:

| Decision | Selection |
|---|---|
| Repository layout | Develop the provider under `provider/` in this repository |
| First release scope | Sandbox and private disk image resources plus data sources |
| Destroy behavior | Delete by default with explicit retain opt-in |
| ARM scope | Data-plane only; keep SandboxGroup ARM management in the existing module |
| Imperative operations | Do not expose exec, shell, or file operations through Terraform |

These choices should be recorded as architecture decision records under
`provider/docs/design/` when implementation begins.

## 4. API and SDK baseline

### 4.1 Inspected SDK

The behavioral inventory in this plan was derived from:

- Official Sandbox Python SDK quickstart.
- `azure-containerapps-sandbox==0.1.0b4`, downloaded and inspected on
  September 3, 2026.
- The SDK's synchronous clients, models, request serialization, polling
  implementations, and error handling.
- Live behavior already observed while deploying the repository's Sandbox
  examples.

The inspected package describes itself as a community preview/beta. Before
implementation starts, repeat the inventory against the newest package and
compare every changed path, model, enum, and terminal state.

### 4.2 Current data-plane contract

| Item | Current value |
|---|---|
| API version | `2026-02-01-preview` |
| Regional endpoint | `https://management.{region}.azuredevcompute.io` |
| OAuth scope | `https://dynamicsessions.io/.default` |
| Group path | `/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/sandboxGroups/{sandboxGroup}` |
| Sandbox collection | `{groupPath}/sandboxes` |
| Disk image collection | `{groupPath}/diskimages` |

The provider must treat these as versioned configuration, not permanent
constants. The default API version and public-cloud token scope can be compiled
defaults, while advanced overrides remain available for service testing.

### 4.3 Relevant Python SDK operations

The table is an inventory of the inspected SDK implementation. It is not a
substitute for a published service contract. Phase 0 must live-verify every v1
row before the provider treats it as stable behavior.

| SDK operation | HTTP behavior derived from SDK | Provider use | Evidence status |
|---|---|---|---|
| `list_sandboxes` | `GET {groupPath}/sandboxes` with optional label filter | Recovery, diagnostics, future list data source | SDK-derived |
| `get_sandbox` | `GET {groupPath}/sandboxes/{id}` | Resource Read/import | SDK-derived |
| `begin_create_sandbox` | `PUT {groupPath}/sandboxes`, then poll GET until `Running` | Resource Create | SDK-derived; create flow exercised indirectly through CLI |
| `begin_delete_sandbox` | `DELETE {groupPath}/sandboxes/{id}`, then poll GET until 404 | Resource Delete | SDK-derived; not exercised against preserved reproductions |
| `list_disk_images` | `GET {groupPath}/diskimages` | Recovery and diagnostics | SDK-derived |
| `get_disk_image` | `GET {groupPath}/diskimages/{id}` | Resource Read/import | SDK-derived |
| `begin_create_disk_image` | `PUT {groupPath}/diskimages`, then poll `status.state` until `Ready` | Resource Create | SDK-derived; image import exercised indirectly through CLI |
| `begin_delete_disk_image` | `DELETE {groupPath}/diskimages/{id}`, then poll GET until 404 | Resource Delete | SDK-derived; not exercised against preserved reproductions |
| `get_public_disk_image` | `GET {groupPath}/diskimages/public/{name}` | Public-image data source | SDK-derived |
| `set_lifecycle_policy` | `POST {sandboxPath}/lifecycle` | In-place Sandbox update | SDK-derived |
| `set_egress_policy` | `POST {sandboxPath}/egresspolicy` | In-place Sandbox update | SDK-derived; running-state requirement must be verified |
| `update_ports` | `PUT {sandboxPath}/ports` | In-place Sandbox update | SDK-derived |
| `stop` / `resume` | `POST {sandboxPath}/stop` or `/resume` | Optional internal update helper only | SDK-derived |

The SDK does not use ARM `Azure-AsyncOperation` or `Location` polling for these
data-plane operations. It polls the resource itself. Its pollers tolerate a
temporary 404 after Create, but that tolerance is not proof that every service
deployment exhibits eventual consistency.

### 4.4 Service characteristics that affect Terraform

1. Sandbox and disk image creation use collection-level PUT requests and the
   service generates the object ID. The caller cannot select a stable ID.
2. A lost create response can be ambiguous: the operation may have succeeded
   even though the client received an error.
3. Sandboxes transition through operational states such as `Creating`,
   `Running`, `Stopping`, `Stopped`, `Suspended`, `Resuming`, and `Deleting`.
4. Disk images expose a separate `status.state`, including `Ready` and `Failed`.
5. The SDK models delete completion as GET returning 404.
6. The SDK resumes a stopped Sandbox before an egress update; Phase 0 must
   verify whether the service actually requires this.
7. Some Sandbox fields have no update endpoint and therefore require Terraform
   replacement.
8. SandboxGroup data-plane authorization can return 403 while a new role
   assignment is propagating.
9. API availability is region, subscription, cloud, and rollout dependent.
10. The API is preview and may add fields or change response casing without a
    corresponding Terraform configuration change.

Phase 0 must verify the service behavior behind each SDK-derived assumption and
bound post-create 404 tolerance to the create operation only.

## 5. Scope

### 5.1 Version 1 scope

Version 1 means the first useful preview release, expected to use a `0.x`
semantic version while the service contract remains preview.

It includes:

- Azure token authentication without external process requirements in hosted
  environments.
- Azure CLI authentication as an optional local-development credential, not a
  mandatory runtime dependency.
- Public Azure regional endpoints.
- Custom HTTPS endpoint and token-scope overrides for controlled testing.
- SandboxGroup ARM ID parsing.
- Sandbox disk image create, read, import, and delete/retain.
- Sandbox create, read, supported in-place updates, import, and delete/retain.
- Public disk image lookup.
- Polling, timeouts, eventual-consistency handling, structured diagnostics, and
  safe create-response recovery.
- Migration documentation for resources created by
  `experimental/sandbox_workload`.

### 5.2 Explicit non-goals for version 1

- Creating or deleting ARM SandboxGroups.
- Creating VNet connections or role assignments.
- Shell execution or command actions.
- Reading, writing, listing, or deleting files.
- Exposing a terminal or interactive session.
- Managing transient stop/resume state as Terraform desired state.
- Snapshot resources or snapshot restore.
- Volume resources or volume mounts.
- Secret resources, peeking secret values, or listing secret keys.
- Egress decision logs and live resource statistics.
- Embedding the Python SDK.
- Calling ACA CLI, Azure CLI, PowerShell, or Python for resource operations.
- Claiming sovereign cloud support before endpoints and token scopes are published
  and tested.

### 5.3 Later resource candidates

| Candidate | Earliest phase | Important prerequisite |
|---|---|---|
| `aca_sandbox_snapshot` | Post-v1 | Validate creation visibility, restore restrictions, and delete behavior |
| `aca_sandbox_volume` | Post-v1 | Validate all volume types and attachment/delete conflicts |
| `aca_sandbox_secret` | Post-v1 | Define write-only values, rotation versioning, and non-disclosing Read behavior |
| Snapshot source for `aca_sandbox` | With snapshot resource | Solve create recovery because snapshot restore rejects labels |
| Volume mounts on `aca_sandbox` | With volume resource | Confirm mounts are returned by GET and can be removed or replaced |

## 6. Repository and release layout

### 6.1 Proposed tree

```text
provider/
|-- go.mod
|-- go.sum
|-- main.go
|-- tools.go
|-- internal/
|   |-- auth/
|   |   `-- credential.go
|   |-- client/
|   |   |-- client.go
|   |   |-- errors.go
|   |   |-- pager.go
|   |   |-- polling.go
|   |   |-- sandboxes.go
|   |   `-- disk_images.go
|   |-- ids/
|   |   |-- group_id.go
|   |   `-- resource_url.go
|   |-- models/
|   |   |-- sandbox.go
|   |   |-- disk_image.go
|   |   |-- egress.go
|   |   |-- lifecycle.go
|   |   `-- ports.go
|   `-- provider/
|       |-- provider.go
|       |-- provider_data.go
|       |-- resource_sandbox.go
|       |-- resource_sandbox_disk_image.go
|       |-- data_source_sandbox.go
|       |-- data_source_sandbox_disk_image.go
|       `-- data_source_public_disk_image.go
|-- docs/
|   |-- design/
|   |-- guides/
|   |-- resources/
|   `-- data-sources/
|-- examples/
|   |-- provider/
|   |-- resources/
|   `-- data-sources/
|-- internal-test/
|   `-- testserver/
`-- scripts/
    `-- build.ps1
```

Tests should live beside the Go files they exercise. The `internal-test`
directory is only for shared fake-server and acceptance-test infrastructure.

### 6.2 Provider identity

Because the repository is already named `terraform-provider-aca`, the natural
provider source is `Azure/aca`, with Terraform type names prefixed by `aca_`.

This is broader than Sandbox and leaves room for other direct ACA APIs later.
The first implementation must still remain data-plane-only and must not
duplicate AzureRM or AzAPI ARM resources.

### 6.3 Monorepo release constraint

Keeping the module and provider in one repository couples their Git tags and
release history. It also complicates Terraform Registry documentation because
the repository already contains module-oriented documentation.

Before the first public Registry release, choose and document one of:

1. Use a synchronized repository version for both the module and provider.
2. Keep provider releases as prereleases while incubating under `provider/`,
   then extract the provider to a dedicated repository.

The selected plan for now is option 2 during development. A public Registry
release is a separate readiness gate, not an MVP coding milestone. Development
and preview validation use a filesystem mirror, Terraform CLI development
override, GitHub release artifact, or approved private registry. Publishing to
the `Azure` Registry namespace also requires repository-owner release and
namespace approvals; the implementation plan must not assume them.

## 7. Provider configuration and authentication

### 7.1 Configuration principle

Provider configuration should contain authentication and API defaults only.
Each resource contains its SandboxGroup scope and region. This lets one provider
configuration manage multiple SandboxGroups and regions without provider
aliases.

Example:

```hcl
terraform {
  required_providers {
    aca = {
      source  = "Azure/aca"
      version = "~> 0.1"
    }
  }
}

provider "aca" {}

resource "aca_sandbox_disk_image" "interpreter" {
  sandbox_group_id = module.sandbox_group.id
  location         = var.location
  name             = "python-interpreter"
  base_image       = "${azurerm_container_registry.acr.login_server}/python@${local.digest}"

  managed_identity_client_id = data.azuread_service_principal.sandbox_group.client_id
}
```

Live validation on September 3, 2026 found that the Sweden Central
`2026-02-01-preview` rollout rejected both SDK-style resource identity and
client-ID ACR pulls despite valid identity attachment and AcrPull. The
deployable private-image example therefore uses the provider's write-only
registry credential path with a repository-scoped ACR token.

This source/version example represents the future published form. During
incubation, examples use the documented preview distribution mechanism rather
than assuming the public Registry entry exists.

### 7.2 Provider schema

| Attribute | Behavior |
|---|---|
| `tenant_id` | Optional explicit tenant override |
| `client_id` | Optional service principal, workload identity, or managed identity client ID |
| `client_secret` | Optional, sensitive; service-principal authentication |
| `client_certificate_path` | Optional service-principal certificate path |
| `client_certificate_password` | Optional and sensitive |
| `oidc_token_file_path` | Optional workload/federated identity token file |
| `use_managed_identity` | Optional explicit managed identity selection |
| `use_azure_cli` | Optional local-development fallback |
| `authority_host` | Optional Entra authority override |
| `disable_instance_discovery` | Optional support for disconnected/private authority scenarios |
| `token_scope` | Optional; defaults to `https://dynamicsessions.io/.default` |
| `api_version` | Optional; defaults to `2026-02-01-preview` |
| `allow_custom_endpoint` | Optional, default false; required for hosts outside the ACA Sandbox endpoint suffix |
| `user_agent` | Optional suffix appended to the provider user agent |

Exact credential conflicts and environment-variable precedence must be covered
by unit tests and provider documentation.

### 7.3 Credential precedence

Implement a deterministic credential factory using Azure SDK for Go
`azidentity`. Do not use `DefaultAzureCredential`, because its internal chain
does not expose the precise inclusion, exclusion, and managed-identity probe
controls required by provider configuration.

1. Explicit client secret configuration.
2. Explicit client certificate configuration.
3. Explicit workload identity/federated token file.
4. Explicit managed identity.
5. Azure CLI credential only as a local fallback when explicitly enabled or
   selected by the documented default for an interactive local environment.

Build an explicit `ChainedTokenCredential` only from the selected credential
types. Map standard `AZURE_*` environment variables into those explicit
credentials. Do not probe IMDS unless managed identity is enabled or is the
only applicable hosted-environment credential. Do not add an Azure PowerShell
credential.

### 7.4 Resource scope

Every resource and data source requires:

- `sandbox_group_id`: canonical ARM resource ID, for example
  `/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.App/sandboxGroups/{group}`.
- Either:
  - `location`: canonical Azure location name such as `swedencentral`, from
    which the public endpoint is derived; or
  - `endpoint`: explicit HTTPS data-plane endpoint.

`location` and `endpoint` are mutually exclusive. The derived endpoint must
match `management.{region}.azuredevcompute.io`. An explicit endpoint is accepted
without additional configuration only when its host is `azuredevcompute.io` or
a subdomain of it.

Any other host requires all of:

- `allow_custom_endpoint = true` in provider configuration.
- An explicitly configured `token_scope`.
- HTTPS.

This prevents a configuration-supplied endpoint from receiving a
`dynamicsessions.io` token by accident. Custom endpoint support exists for
controlled private/test scenarios and does not imply that the service is
deployed in that cloud or region.

### 7.5 Authorization

The provider does not create role assignments. Its documentation and examples
must require the executing principal to have the SandboxGroup data-plane role,
currently `Container Apps SandboxGroup Data Owner`, at the appropriate scope.

On 403, diagnostics should distinguish likely RBAC propagation from permanent
authorization failure and include the group ARM ID, but never print tokens or
authorization headers.

## 8. Native REST client architecture

### 8.1 Client factory

Provider `Configure` should create:

- One shared `azcore.TokenCredential`.
- One shared HTTP transport and connection pool.
- A concurrency-safe client cache keyed by endpoint, token scope, API version, and
  SandboxGroup ARM ID.

The group ARM ID parser extracts subscription ID, resource group, and
SandboxGroup name, then constructs the data-plane group path used by the Python
SDK.

### 8.2 HTTP pipeline

Use Azure SDK for Go `azcore` policies for:

- Bearer token acquisition.
- Request IDs and correlation IDs.
- User agent.
- Proxy support.
- Retry hints such as `Retry-After`.
- Structured `azcore.ResponseError` handling.

Add provider-specific policies for:

- Redacting authorization, registry credentials, environment secrets, and
  sensitive response fields.
- Validating continuation URLs as HTTPS and same-host before following them.
- Rejecting an unapproved configured endpoint before token acquisition.
- Classifying transient RBAC propagation failures.
- Disabling unsafe automatic retries for collection-level create operations.

### 8.3 Retry policy

Safe retry rules:

- Retry GET and list requests on 408, throttling 429 responses, and transient 5xx responses with
  exponential backoff and jitter.
- Honor `Retry-After`.
- Retry only known authorization-propagation 403 error codes for a bounded,
  configurable window, initially no more than about 60 seconds.
- Fail fast on quota/capacity 429 error codes instead of treating them as
  generic throttling.
- Treat GET 404 after Create as eventual consistency until the create timeout.
- Treat GET 404 during Read as remote deletion and remove the resource from
  Terraform state.
- Treat GET 404 during Delete as success.

Unsafe retry rules:

- Do not blindly replay `PUT {groupPath}/sandboxes`.
- Do not blindly replay `PUT {groupPath}/diskimages`.
- Do not retry a write after an ambiguous connection failure unless the
  provider first proves whether the object was created.

### 8.4 Create-response recovery

The service-generated ID and collection-level create endpoint are the largest
provider correctness risk.

For normal Sandbox and disk-image creation:

1. Require a provider-level logical `name`.
2. Treat `name` as unique among provider-managed objects of the same type in a
   SandboxGroup. Concurrent workspaces must coordinate unique names.
3. Add reserved labels:
   - `managed_by = "terraform-provider-aca"`
   - `tf_aca_name = <logical name>`
   - `tf_aca_create_fingerprint = <non-secret create-only configuration hash>`
4. Reject user labels that overwrite reserved keys.
5. Before sending Create, list by `tf_aca_name`:
   - If no object exists, proceed.
   - If one exists, fail with an import instruction instead of silently
     adopting it.
   - If multiple exist, fail and report their IDs.
6. Serialize same-process creates for the same group/type/name with a keyed
   mutex. This reduces, but cannot eliminate, cross-process races.
7. Send the create request once.
8. If the response is lost or ambiguous, perform bounded read-after-write
   discovery using both `tf_aca_name` and `tf_aca_create_fingerprint`.
9. If exactly one object is discovered, immediately write its service ID,
   scope, and canonical URL to Terraform partial state before returning any
   remaining error diagnostic. This allows the next apply to refresh the
   object instead of creating or importing it manually.
10. If Terraform is run again after a failed apply and the object remains but
    partial state was not persisted, fail with a precise import command rather
    than creating another object.

Sandbox list supports server-side label filtering. Disk image recovery must
page through private images and filter labels client-side unless the service
adds a label filter. Cache a disk-image listing within one apply operation and
invalidate it after every disk-image write to avoid O(n-squared) scans.

The create fingerprint includes only fields that never change in place. Read
must remove all reserved labels before writing the user `labels` attribute.
In-place lifecycle, egress, and port updates do not modify the create
fingerprint.

There remains a cross-process time-of-check/time-of-use race until the service
supports caller-selected IDs or idempotency keys. If recovery finds multiple
matching objects, the provider must not delete any of them; it reports all IDs
and requires manual selection/import.

Snapshot restore is excluded from v1 because the inspected SDK rejects labels
on snapshot restore, removing this recovery mechanism.

## 9. Terraform resources and data sources

### 9.1 Resource matrix

| Terraform type | v1 | CRUD/API |
|---|---:|---|
| `aca_sandbox_disk_image` resource | Yes | Create, Read, Delete/Retain, Import |
| `aca_sandbox` resource | Yes | Create, Read, selective Update, Delete/Retain, Import |
| `aca_sandbox_disk_image` data source | Yes | Get private image by ID |
| `aca_sandbox` data source | Yes | Get Sandbox by ID |
| `aca_sandbox_public_disk_image` data source | Yes | Get public image by name |
| List-all data sources | No | Add only with demonstrated use and bounded state |
| Snapshot resource | No | Phase 2 |
| Volume resource | No | Phase 2 |
| Secret resource | No | Phase 2 |

### 9.2 `aca_sandbox_disk_image`

Proposed schema:

| Attribute | Terraform behavior | API mapping |
|---|---|---|
| `sandbox_group_id` | Required, replace on change | Group path |
| `location` | Optional, conflicts with `endpoint`, replace on change | Regional endpoint |
| `endpoint` | Optional, conflicts with `location`, replace on change | Explicit endpoint |
| `name` | Required, replace on change | Reserved/name labels |
| `base_image` | Required, replace on change | `image.base` |
| `entrypoint` | Optional list, replace on change | `image.entrypoint` |
| `command` | Optional list, replace on change | `image.cmd` |
| `labels` | Optional map, replace on change | `labels`, merged with reserved labels |
| `managed_identity_resource_id` | Optional, conflicts with client ID and registry credentials, replace on change | `managedIdentityResourceId` |
| `managed_identity_client_id` | Optional, conflicts with resource ID and registry credentials, replace on change | `managedIdentityClientId` |
| `registry_username` | Optional, sensitive as appropriate, replace on change | `registryCredentials.username` |
| `registry_token_wo` | Optional, sensitive and write-only; consumed only during Create | `registryCredentials.token` |
| `deletion_policy` | Optional `Delete` or `Retain`, default `Delete` | Provider behavior |
| `id` | Computed | Service-generated image ID |
| `resource_url` | Computed | Canonical data-plane URL |
| `status` | Computed | `status.state` |
| `status_message` | Computed | `status.message` |

Validation:

- Require exactly one authentication mode for a private registry when the
  service needs credentials: managed identity or username/token.
- Warn when `base_image` is tag-based rather than digest-pinned.
- Reject empty path segments and non-HTTPS endpoints.
- Reject reserved label keys.

All remote disk-image fields are replacement-only in v1 because the SDK exposes
no disk-image update endpoint.

Changing registry credentials alone does not replace a completed disk image.
The credentials are build-time inputs, not remote disk-image state. New
credentials are used if another configuration change replaces the image.

Create completes only when `status.state` is `Ready` or `Succeeded`. `Failed`
is terminal and the diagnostic includes the service status message.

### 9.3 `aca_sandbox`

Proposed top-level schema:

| Attribute/block | Terraform behavior |
|---|---|
| `sandbox_group_id` | Required, replace on change |
| `location` / `endpoint` | Exactly one, replace on change |
| `name` | Required logical Terraform name, replace on change |
| `source` | Required nested block, replace on change |
| `resources` | Required nested block, replace on change |
| `labels` | Optional map, replace on change |
| `environment` | Optional non-sensitive map, replace on change |
| `environment_wo` | Optional sensitive write-only map, replace when version changes |
| `environment_wo_version` | Optional integer replacement trigger |
| `connections` | Optional set of connection names, replace on change |
| `auto_suspend` | Optional nested block, in-place update |
| `egress_policy` | Optional nested block, in-place update |
| `ports` | Optional map of nested port definitions, in-place update |
| `entrypoint` | Optional list, replace on change |
| `command` | Optional list, replace on change |
| `skip_egress_proxy` | Optional advanced boolean, replace on change |
| `customer_vnet_connection_name` | Optional, replace on change |
| `vmm_type` | Optional advanced string, replace on change |
| `allow_resume_for_updates` | Optional provider behavior flag, default false |
| `deletion_policy` | Optional `Delete` or `Retain`, default `Delete` |
| `id` | Computed service-generated ID |
| `state` | Computed operational state |
| `hostname` | Computed |
| `management_url` | Computed and sensitive if the service contract requires it |
| `created_at` | Computed |
| `region` | Computed |
| `resource_url` | Computed canonical data-plane URL |

#### Source block

Version 1 supports exactly one of:

```hcl
source {
  public_disk_image = "ubuntu"
}
```

```hcl
source {
  private_disk_image_id = aca_sandbox_disk_image.interpreter.id
}
```

```hcl
source {
  preset = "..."
}
```

Snapshot restore is deferred because the SDK applies materially different
validation and the service rejects the labels needed for safe create recovery.

#### Resources block

```hcl
resources {
  cpu    = "1000m"
  memory = "2048Mi"
  disk   = "20Gi"
}
```

CPU, memory, and disk changes replace the Sandbox because no resource resize
operation is exposed by the inspected SDK.

#### Auto-suspend block

```hcl
auto_suspend {
  enabled          = true
  interval_seconds = 300
  mode             = "Memory"
}
```

`mode` accepts `Memory` or `Disk`. Auto-delete is not included in v1. A
Terraform-managed object that deletes itself creates continual recreation and
retention ambiguity.

#### Egress policy

Support the full declarative policy represented by the SDK:

- `default_action`: `Allow` or `Deny`.
- Host allow/deny rules.
- Transform and rewrite rules.
- Match host, path, and HTTP methods.
- Header set, insert, and remove operations.
- Secret references.
- System-assigned and user-assigned managed identity references.
- Traffic inspection mode when confirmed by live contract tests.

Egress changes use the policy replacement endpoint. The provider must validate
the complete policy before sending any update. Phase 0 must verify whether the
service rejects egress changes on a stopped or suspended Sandbox.

If running state is required:

- Default behavior is to fail with an actionable diagnostic.
- `allow_resume_for_updates = true` permits the provider to resume the Sandbox,
  emit a warning, apply the update, and leave it running.

The provider does not silently introduce a billable operational state change.

#### Ports

Use a map keyed by a user-selected logical name rather than a Terraform set:

```hcl
ports = {
  mcp = {
    port            = 8080
    protocol        = "Http"
    activation_mode = "OnDemand"

    auth = {
      anonymous = false
      entra_id = {
        enabled = true
        emails  = ["developer@example.com"]
      }
    }
  }
}
```

The logical key is Terraform-only. API responses are matched back to configured
entries by unique port number. Each map entry exports computed `host_port` and
`url`.

Port validation mirrors the SDK:

- Unique port numbers.
- Authentication modes are mutually exclusive.
- IP access-control policy requires an explicit default action.
- Maximum 10 IP rules.
- Maximum 10 CIDRs per rule.
- Priorities between 0 and 1000 and unique within a port.
- Rule names are 1-63 alphanumeric/hyphen characters.
- CIDRs must be canonical network addresses, not host addresses with a prefix.

#### Sensitive environment values

Offer separate normal and write-only maps:

- `environment` is for non-sensitive values and participates in normal state
  and drift comparison.
- `environment_wo` is write-only and never enters plan or state.
- `environment_wo_version` is stored and triggers replacement when changed.

The provider must never populate `environment_wo` from GET responses and must
not log the server-returned environment document.

### 9.4 Sandbox update semantics

In-place:

- `auto_suspend`
- `egress_policy`
- `ports`
- `deletion_policy` because it is provider-only

Replacement:

- Scope or endpoint
- Source
- CPU, memory, or disk
- Labels or logical name
- Environment
- Connections
- Entrypoint or command
- Egress proxy bypass
- Customer VNet connection
- VMM type

Update algorithm:

1. Validate every planned nested object before making a write.
2. Read the current Sandbox and reject updates in terminal states.
3. Resume only when the API is verified to require `Running` and
   `allow_resume_for_updates` is true.
4. Apply supported updates in a deterministic order.
5. Read the complete Sandbox after the final update.
6. If an intermediate update fails, return a diagnostic that states which
   operations completed and preserve enough refreshed state for the next plan
   to reconcile the remainder.

The provider does not attempt to force a Sandbox back to stopped/suspended after
an update. Operational state remains computed rather than desired state.

## 10. State, identity, and import

### 10.1 Canonical state identity

State must contain:

- SandboxGroup ARM ID.
- Location or explicit endpoint.
- Service-generated object ID.
- Canonical data-plane resource URL.

The service object ID alone is not enough to reconstruct the client and should
not be the sole import identifier.

### 10.2 Import format

Use the full data-plane resource URL without a query string:

```text
https://management.swedencentral.azuredevcompute.io/subscriptions/{sub}/resourceGroups/{rg}/sandboxGroups/{group}/sandboxes/{sandboxId}
```

```text
https://management.swedencentral.azuredevcompute.io/subscriptions/{sub}/resourceGroups/{rg}/sandboxGroups/{group}/diskimages/{imageId}
```

The import parser:

- Requires HTTPS.
- Validates all path segments.
- Accepts only the exact supported resource collection.
- Extracts host, subscription, resource group, group name, and object ID.
- Reconstructs the canonical SandboxGroup ARM ID.
- Reverse-maps `management.{region}.azuredevcompute.io` to `location = region`
  and leaves `endpoint` null so an imported resource matches normal
  location-based configuration.
- Stores `endpoint` only when the host cannot be represented as the standard
  regional public-cloud pattern.
- Rejects query parameters, fragments, traversal, and unsupported hosts when a
  custom endpoint has not been enabled.

### 10.3 Read behavior

- GET 200: normalize the response into state.
- GET 404: remove the resource from state.
- Transient 404 immediately after Create: continue polling until timeout.
- Unknown preview fields: ignore unless they affect a configured invariant.
- Response casing differences: normalize known enum values to canonical SDK
  casing.
- Lists returned in unstable order: sort or map them before writing state.
- Reserved labels: remove provider keys before writing the user `labels`
  attribute.

For Optional replacement-only attributes, configuration/state is authoritative.
Read must not overwrite an omitted or configured value with a service default
that would cause a replacement. Specifically:

- Preserve prior state for create-only attributes when the service omits them
  or returns an equivalent normalized value.
- Write a changed remote value only when it represents observable out-of-band
  drift that the API can reliably report.
- During import, populate every reliably readable create-only value so the
  subsequent configuration can be reconciled.
- Use explicit semantic normalization and plan modifiers per attribute; do not
  rely on a generic "write all server defaults" mapper.
- Keep computed service defaults in separate computed attributes when users
  need to observe them.

Every Optional replacement-only attribute requires a test proving that omission
and service defaulting still produce an empty second plan.

### 10.4 State upgrades

Start with schema version 1 and add explicit state upgrade functions whenever:

- An import identifier changes shape.
- A nested object changes representation.
- A scalar becomes a structured value.
- A provider-only retention field changes semantics.
- API casing or default normalization changes stored state.

Never rely on users editing state manually.

## 11. Delete and retention contract

Each managed resource exposes:

```hcl
deletion_policy = "Delete" # default
```

or:

```hcl
deletion_policy = "Retain"
```

`Delete` behavior:

1. Send DELETE once.
2. Treat 404 as success.
3. Poll GET until 404.
4. Surface dependency conflicts such as an attached/in-use disk image rather
   than silently retaining it.
5. Do not cascade-delete snapshots, disk images, volumes, secrets, or other
   objects not represented by the resource being deleted.

`Retain` behavior:

1. Do not call the remote DELETE endpoint.
2. Remove the object from Terraform state.
3. Emit a warning with the retained object ID and canonical import URL.
4. Clearly document that Terraform no longer monitors or updates the object.

For strong protection against accidental removal from configuration, examples
for investigation/reproduction workloads should also use:

```hcl
lifecycle {
  prevent_destroy = true
}
```

`prevent_destroy` blocks the operation. `deletion_policy = "Retain"` allows the
Terraform destroy to complete while intentionally orphaning the remote object.
They solve different problems.

Changing from `Retain` to `Delete` is a state-only update. It does not
immediately delete the remote object.

Terraform destroy uses the retention value already recorded in state. A user
who changes `deletion_policy` must apply that change before running destroy;
changing the configuration and destroying in one step is not a safe retention
workflow.

If Delete times out or returns an unresolved error, the provider returns an
error and keeps the resource in state. It removes state only after confirmed
404 or an explicit `Retain` operation.

## 12. Polling and timeouts

### 12.1 Default timeouts

| Resource operation | Default |
|---|---:|
| Sandbox Create | 5 minutes |
| Sandbox Update | 5 minutes |
| Sandbox Delete | 5 minutes |
| Disk image Create | 15 minutes |
| Disk image Delete | 5 minutes |

Support standard Terraform custom resource timeouts.

These defaults are provisional SDK-derived starting points. Phase 0 contract
tests must measure realistic image sizes and Sandbox startup times before the
defaults are released.

### 12.2 Poll rules

Sandbox Create:

- Success: `Running`
- Failure: `Failed`, `Deleting`, or a service error
- In progress: `Creating`, `Resuming`, empty/unknown, or transient 404

Disk image Create:

- Success: `Ready` or `Succeeded`
- Failure: `Failed`
- In progress: any other non-terminal state or transient 404

Delete:

- Success: GET 404
- In progress: GET 200 with any state, including `Deleting`

Use context cancellation, exponential backoff with bounded jitter, and a
monotonic deadline. Diagnostics must include the last observed state and status
message without dumping the full potentially sensitive response.

## 13. Error handling

Implement a typed service error containing:

- HTTP status.
- Service error code.
- Sanitized message.
- Request/correlation ID.
- Retry-after value.
- Operation and canonical resource URL.

Map common cases:

| Status/condition | Terraform behavior |
|---|---|
| 400 validation | Attribute/path diagnostic where possible |
| 401 | Authentication diagnostic |
| 403 with known propagation code during initial access | Bounded retry, then authorization diagnostic |
| 404 on Read | Remove state |
| 404 during post-create poll | Eventual-consistency retry |
| 409 in-use/conflict | Preserve state and report actionable conflict |
| 409 Sandbox not running | Resume only for operations documented to require it |
| 429 throttling code | Retry with service delay |
| 429 quota/capacity code | Fail fast with quota diagnostic |
| 5xx | Retry safe reads; do not blindly replay creates |

No broad catch-and-ignore behavior is allowed. The Python SDK's
`ensure_running` helper currently ignores one resume error because another
actor may already be resuming; the Go provider should instead re-read state and
prove that the operation is progressing before continuing.

## 14. Security requirements

1. No external command execution.
2. No credentials in process arguments.
3. No credentials, authorization headers, environment secrets, or secret
   response bodies in logs or diagnostics.
4. Use Terraform write-only arguments for registry tokens and sensitive
   environment values.
5. Store only non-reversible hashes in provider private state when needed to
   detect write-only input changes.
6. Require HTTPS endpoints and allowlist the ACA Sandbox host suffix by default.
7. Validate redirect and continuation hosts before forwarding authorization.
8. Prefer managed identity or workload identity over registry passwords.
9. Mark computed URLs sensitive if they embed a bearer token or other secret;
   verify the actual service URL contract before final schema.
10. Reject path traversal and malformed subscription/resource/group/object
    segments.
11. Bound response body sizes used in error messages.
12. Keep dependency versions patched and use Go vulnerability scanning in CI.

Registry credential fallback remains supported because the Python SDK exposes
it, but the main examples should use managed identity. Live acceptance testing
must confirm managed-identity disk import before declaring that path supported.

## 15. Testing strategy

### 15.1 Unit tests

Unit tests run without Azure and cover:

- Provider schema and credential conflicts.
- SandboxGroup ARM ID parsing.
- Regional endpoint construction.
- Import URL parsing and canonicalization.
- Request path, method, query, headers, and JSON bodies.
- Response model normalization.
- Reserved-label merge and collision rejection.
- Fingerprint stability and secret exclusion.
- Every plan modifier and replacement rule.
- Port and CIDR validation.
- Egress policy serialization.
- Write-only input behavior.
- Delete versus retain behavior.
- Polling terminal states, timeout, cancellation, jitter, and transient 404.
- Same-host continuation validation.
- Error redaction and status mapping.
- Ambiguous create-response recovery.
- Pagination over private disk images.

Use an in-process TLS test server and an injectable clock/sleeper. Do not use
recorded real authorization headers or production response payloads containing
customer data.

### 15.2 Contract tests

Add opt-in contract tests against a controlled SandboxGroup to detect preview
API changes:

- Verify request/response casing and field names.
- Verify the current API version.
- Verify endpoint/token-scope authentication.
- Verify object IDs and list pagination.
- Verify terminal states.
- Verify 404 eventual consistency after create.
- Verify lifecycle, egress, and port update behavior.
- Verify managed-identity disk import from ACR.
- Verify registry credential fallback without logging the token.

Contract tests should fail clearly when the API is unavailable in the selected
subscription or region rather than silently skipping a changed contract.

### 15.3 Terraform acceptance tests

Use `terraform-plugin-testing` with protocol version 6 provider factories.
Acceptance tests require `TF_ACC=1`, a dedicated test subscription, a dedicated
resource group, an existing SandboxGroup, and the data-plane role assignment.

Minimum matrix:

#### Disk image

- Create from digest-pinned image with managed identity.
- Create with write-only registry credential fallback.
- Read and no-change plan.
- Import by canonical URL.
- Out-of-band delete removes state.
- Terraform Delete reaches 404.
- Retain removes state but preserves the image.
- Failed image build returns status message.

#### Sandbox

- Create from a public disk image.
- Create from a private `aca_sandbox_disk_image`.
- Read and no-change plan.
- Update auto-suspend.
- Update default-deny egress and host rules.
- Update named ports and verify computed URLs.
- Refresh while stopped/suspended produces no replacement.
- Import by canonical URL.
- Out-of-band delete removes state.
- Terraform Delete reaches 404.
- Retain removes state but preserves the Sandbox.
- Invalid port ACL fails before any API write.

Ambiguous response and connection-loss recovery is validated with the local
fault-injecting TLS server, where the server can commit a create and terminate
the client response deterministically. Live acceptance tests verify the normal
no-duplicate preflight and import paths but do not claim to induce a lost
response reliably.

#### Portability

- Build and unit test on Linux, Windows, and macOS.
- Run at least one acceptance path on Linux.
- Prove no ACA CLI, PowerShell, Python, or Azure CLI is required when workload
  identity, managed identity, or service-principal authentication is selected.

### 15.4 Test cleanup

Acceptance-test resources use `deletion_policy = "Delete"` and unique reserved
labels. A separate cleanup utility may list only resources with the acceptance
test run ID and require explicit confirmation before deletion.

Never point cleanup automation at the preserved reproduction SandboxGroup.

## 16. Documentation and examples

Provider documentation must include:

- Authentication guide for local development, GitHub Actions, HCP Terraform,
  Azure-hosted runners, and managed identity.
- Required SandboxGroup data-plane role.
- Public Azure endpoint construction and custom endpoint limitations.
- Resource lifecycle and replacement tables.
- Delete versus retain semantics.
- Import examples using quoted full URLs.
- Write-only registry and environment inputs.
- Preview API and region availability warning.
- Troubleshooting for 401, 403 propagation, 404 eventual consistency, 409
  conflicts, and timeouts.

Initial examples:

1. Public Ubuntu Sandbox with default-deny egress.
2. ACR image imported as a disk with managed identity, then used by a Sandbox.
3. Retained investigation Sandbox protected by `prevent_destroy`.
4. Importing an object preserved by `experimental/sandbox_workload`.

The existing `examples/sandbox_code_interpreter` should be migrated only after
the provider supports all declarative features it requires. The application
container and MCP server remain examples; only the CLI-backed provisioning path
is replaced.

## 17. Migration from `experimental/sandbox_workload`

### 17.1 Principles

- Never delete existing preserved Sandboxes or disk images as part of migration.
- Do not silently adopt an object selected only by a non-unique name.
- Require the exact group, endpoint, and service object ID.
- Preserve actual labels by object type:
  - Existing disks use `aca_image_fingerprint` and
    `managed_by = "terraform"`.
  - Existing Sandboxes use the configured selector labels plus
    `aca_config_fingerprint`.
- Produce import commands before removing the experimental module from state.

### 17.2 Migration procedure

1. Upgrade configuration to include the native provider.
2. Use the existing discovery outputs/scripts in read-only mode to obtain:
   - SandboxGroup ARM ID.
   - Regional endpoint.
   - Disk image ID.
   - Sandbox ID.
3. Add matching `aca_sandbox_disk_image` and `aca_sandbox` configuration.
4. Set `deletion_policy = "Retain"` during migration.
5. Import each object using its canonical data-plane URL.
6. Run refresh-only plan and reconcile schema differences.
7. Run a normal plan and require no replacement before removing the
   `experimental/sandbox_workload` state entries.
8. Remove the experimental module from configuration without invoking any
   destroy-time data-plane action.
9. Change `deletion_policy` to the user's intended long-term behavior.

### 17.3 Migration tooling

Add a read-only migration helper that:

- Reads the experimental module's Terraform outputs or explicit IDs.
- Queries GET only.
- Produces HCL skeletons and `terraform import` commands.
- Detects duplicate label matches and refuses to guess.
- Never creates, changes, or deletes a remote object.

## 18. Delivery phases

### Phase 0: Contract freeze and design records

Deliverables:

- Re-run SDK inventory against the newest Python package.
- Capture sanitized live request/response shapes for v1 operations.
- Confirm public-cloud endpoint, token scope, API version, and role behavior.
- Confirm managed-identity ACR image import.
- Confirm whether create requests support an undocumented idempotency header.
- Confirm whether stopped/suspended Sandboxes reject egress or port updates.
- Verify the Terraform 1.11/write-only compatibility floor and document
  OpenTofu compatibility separately.
- Record ADRs for repository/release, authentication, retention, identity,
  create recovery, and minimum Terraform version.

Exit criteria:

- Every v1 field has a confirmed request key, response key, mutability rule, and
  terminal-state rule.
- Unknowns are either resolved or explicitly removed from v1.

### Phase 1: Provider and client scaffold

Deliverables:

- `provider/` Go module.
- Protocol version 6 provider server.
- Provider schema and credential factory.
- Group ID and resource URL parsers.
- Shared REST client, error model, retry policy, pager, and poller.
- Fake TLS service and unit-test harness.

Exit criteria:

- Provider configures without external executables.
- Authentication works with service principal, workload identity, managed
  identity, and Azure CLI local development.
- Client unit tests cover redaction, retry safety, and cancellation.

### Phase 2: Disk image resource

Deliverables:

- Disk image resource and data source.
- Public disk image data source.
- Write-only registry token.
- Managed identity path.
- Polling, import, retain, and ambiguous-create recovery.
- Documentation and acceptance tests.

Exit criteria:

- Digest-pinned ACR image creates and reaches `Ready`.
- Import yields a no-change plan.
- Delete and retain both behave exactly as documented.
- Repeated failed/retried applies do not create duplicate images.

### Phase 3: Sandbox resource

Deliverables:

- Public/private disk source.
- Resources, labels, normal/write-only environment, connections, entrypoint,
  command, VNet connection, and advanced create options.
- Auto-suspend, egress policy, and ports update paths.
- Import, retain, polling, and ambiguous-create recovery.
- Sandbox data source.

Exit criteria:

- Create reaches `Running`.
- Supported updates are in place.
- Unsupported updates plan replacement.
- Stop/suspend state does not cause drift.
- Port URLs are stable in state.
- Import yields a no-change plan.

### Phase 4: Example migration

Deliverables:

- Read-only migration helper.
- Native provider version of `sandbox_code_interpreter`.
- Side-by-side migration guide.
- Deprecation notice on the CLI-backed experimental module.

Exit criteria:

- A preserved disk and Sandbox can be imported without replacement.
- The code-interpreter example applies without Python, PowerShell, ACA CLI, or
  local-exec provisioning dependencies.
- Live health and MCP probes still pass.

### Phase 5: Hardening and preview release

Deliverables:

- Full unit, contract, and acceptance matrix.
- Cross-platform binaries.
- Generated provider documentation.
- Signed prerelease artifacts and checksums.
- Security and dependency review.
- Changelog and support policy.

Exit criteria:

- Known ambiguous-response paths preserve partial state or stop with explicit
  import diagnostics; the remaining cross-process race is documented as a
  service idempotency limitation.
- No credential appears in Terraform state, logs, process arguments, or test
  artifacts.
- Live apply, refresh, update, import, retain, and destroy are repeatable.
- The monorepo Registry release decision is resolved.

### Phase 6: Post-v1 resources

Order:

1. Snapshots and snapshot restore.
2. Volumes.
3. Secrets with write-only values and explicit rotation versions.
4. Additional read-only operational data sources only when state stability is
   demonstrated.

## 19. Definition of done for the first preview

The provider preview is complete only when:

- A user can install one provider binary from the documented preview
  distribution mechanism and run `terraform init` with a filesystem mirror,
  development override, GitHub artifact workflow, or approved private registry.
- No ACA CLI, PowerShell, or Python installation is required.
- ARM SandboxGroup resources can be created by the existing module and consumed
  by provider resources in the same configuration.
- Disk image and Sandbox CRUD/import work against the registered regional API.
- All remote mutations have deterministic polling and timeouts.
- A lost create response cannot produce an unbounded duplicate retry.
- Managed identity is the documented primary ACR authentication path.
- Sensitive fallback credentials use write-only arguments.
- Delete is the default and retain is explicit and tested.
- Retained resources produce exact re-import information.
- Resource Read handles stopped, suspended, and externally deleted objects.
- A second plan after apply is empty.
- Import through both standard regional URLs and approved custom endpoint URLs
  produces an empty plan.
- Cross-platform builds and tests pass.
- Documentation accurately labels the provider and service as preview.
- The migrated code-interpreter example passes live probes without provisioning
  shell-outs.

## 20. Main barriers and what would reduce them

### 20.1 Current barriers

1. Preview API instability and uneven regional/subscription rollout.
2. No inspected official Go SDK for the Sandbox data plane.
3. No confirmed public OpenAPI contract suitable for code generation.
4. Collection-level create endpoints with service-generated IDs.
5. No confirmed idempotency key for create requests.
6. Eventual consistency after create.
7. Partial update surface: some fields have setters, others require replacement.
8. Egress update can change operational state by resuming a Sandbox.
9. Limited readback for some future features, especially volume mounts and
   write-only secret values.
10. RBAC propagation delays and currently preview role behavior.
11. Monorepo release/version/documentation coupling.
12. Live acceptance tests require scarce preview service capacity and careful
    cleanup.

### 20.2 Service improvements that would make the provider easier

- Publish and version the complete data-plane OpenAPI specification.
- Generate an official Azure SDK for Go.
- Accept client-generated resource IDs or an idempotency key on create.
- Return a stable operation ID for long-running operations.
- Provide ETags and conditional update/delete.
- Expose PATCH/PUT operations for labels, environment, resources, connections,
  and mounts.
- Return the complete declarative Sandbox configuration from GET.
- Publish stable error codes and terminal-state enums.
- Publish endpoints and token scopes for every supported Azure cloud and EUAP
  region.
- Provide a test emulator or a dedicated provider integration-test environment.
- Document role definition IDs, propagation expectations, and minimum scopes.
- Define whether delete is immediate, soft-delete, recoverable, or blocked by
  child dependencies.
- Guarantee that credentials and environment secrets are redacted from GET
  responses where write-only semantics are expected.

### 20.3 Repository/process improvements that would make the provider easier

- Assign a service-side API owner who reviews provider contract questions.
- Establish a sanitized contract-test SandboxGroup available to CI.
- Version SDK and provider contract changes together.
- Add preview API changelog notifications.
- Decide the public Registry release model before provider `v1.0.0`.
- Keep the experimental module available as a fallback until the native
  provider covers and migrates its declarative behavior.

## 21. Risks and mitigations

| Risk | Mitigation |
|---|---|
| API changes after provider release | Pin API version, release provider updates, maintain state upgraders |
| Duplicate create after timeout | No blind create retry; reserved labels, fingerprints, read-after-write recovery |
| Retain surprises users | Delete default, explicit enum, warning with import URL, documentation |
| Secrets enter state | Terraform 1.11 minimum, write-only arguments, redacted logging |
| Stopped Sandbox changes unexpectedly | Operational state computed; fail by default and resume only with explicit opt-in |
| Port response order causes drift | Map ports by logical key and match by unique port |
| Service returns new fields/casing | Tolerant read model plus canonical normalization |
| ACR managed identity still returns 401 | Contract gate before declaring support; explicit credential fallback remains available |
| Public Registry conflicts with module releases | Incubate under `provider/`; resolve release model before public publish |
| Unsupported cloud endpoint | Public-cloud host allowlist plus explicit custom endpoint and token-scope opt-in |

## 22. Source references

- Sandbox Python SDK setup:
  `https://sandboxes.azure.com/docs/sandboxes/quickstart/setup-python-sdk`
- Python package:
  `https://pypi.org/project/azure-containerapps-sandbox/`
- SDK repository:
  `https://github.com/microsoft/azure-container-apps`
- Terraform Plugin Framework:
  `https://developer.hashicorp.com/terraform/plugin/framework`
- Terraform provider acceptance tests:
  `https://developer.hashicorp.com/terraform/plugin/framework/acctests`
- Terraform resource import:
  `https://developer.hashicorp.com/terraform/plugin/framework/resources/import`
- Terraform write-only arguments:
  `https://developer.hashicorp.com/terraform/plugin/framework/resources/write-only-arguments`
- Terraform Registry provider publishing:
  `https://developer.hashicorp.com/terraform/registry/providers/publishing`
- Azure SDK for Go identity:
  `https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/azidentity`
