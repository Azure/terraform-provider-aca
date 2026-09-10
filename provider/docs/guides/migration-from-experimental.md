# Migrate from `experimental/sandbox_workload`

The migration is preservation-first. It does not create or delete data-plane
resources.

1. Record the SandboxGroup ARM ID, regional endpoint, disk image ID, and
   Sandbox ID from the experimental module outputs.
2. Add matching `aca_sandbox_disk_image` and `aca_sandbox` resources.
3. Initially set `deletion_policy = "Retain"` on both resources.
4. Import the existing disk and Sandbox by their canonical data-plane URLs.
5. Run a refresh-only plan.
6. Match the existing disk name and labels:
   - `aca_image_fingerprint`
   - `managed_by = "terraform"`
7. For the Sandbox:
   - Preserve selector labels and `aca_config_fingerprint`.
   - Use the Sandbox ID as the provider `name`, because experimental
     Sandboxes do not contain `tf_aca_name`.
   - Use decimal port numbers as Terraform port map keys.
   - Reconfigure environment values; they are not imported.
8. Require a no-replacement normal plan before removing the experimental
   module from state/configuration.
9. Apply the desired long-term `deletion_policy` in a separate operation.

Do not use label-only discovery when multiple objects match. Import exact
service IDs and never delete duplicates as part of migration.
