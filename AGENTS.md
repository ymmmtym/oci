# OCI Terraform (Always Free)

Terraform manages OCI Always Free resources in `ap-osaka-1`. Backend: Terraform Cloud (`yumenomatayume` / `oci` workspace).

## Auth

`.auto.tfvars` (gitignored — never commit):
```hcl
tenancy_ocid = "ocid1.tenancy.oc1..aaaa..."
user_ocid    = "ocid1.user.oc1..aaaa..."
fingerprint  = "xx:xx:xx:..."
region       = "ap-osaka-1"
private_key  = "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
```
`private_key` must use `\n` escapes, not literal newlines. Env var fallback: `TF_VAR_tenancy_ocid`, `TF_VAR_user_ocid`, `TF_VAR_fingerprint`, `TF_VAR_region`, `TF_VAR_private_key`.

Required vars: `tenancy_ocid`, `user_ocid`, `fingerprint`, `region` (default `ap-osaka-1`), `private_key`, `adb_admin_password`. Optional: `alert_webhook_url` (Monitoring alarm webhook destination; empty = no alarm resources) and `alert_webhook_protocol` (`CUSTOM_HTTPS` default, or `SLACK`).

## Tools

Managed via `mise` (`mise.toml`): `oci` and `terraform` (both `latest`).

## Deployed resources (Always Free limits)

| Resource | Status |
|----------|--------|
| VM.Standard.E2.1.Micro × 2 | ✅ Deployed (max 2) |
| Object Storage 20GB | ✅ Deployed (max 20GB) |
| Autonomous Database | ✅ Deployed (default password in `variables.tf`) |
| Monitoring alarm + ONS webhook subscription | ✅ (only when `alert_webhook_url` is set) |
| VM.Standard.A1.Flex (Arm) | ❌ Commented out — capacity issues in ap-osaka-1 |
| Volume backup policy (daily, 5 generations) | ✅ jp-bastion-01 boot volume only |
| Block Volume, Load Balancer | Not created yet |

SSH key is hardcoded in `main.tf` (`oci_core_instance.micro` metadata). Update there to change.

The provider's CustomizeDiff makes changes to `metadata["ssh_authorized_keys"]` and `metadata["user_data"]` ForceNew, so editing either recreates both instances. `ignore_changes = [metadata["user_data"]]` suppresses that for cloud-init only; the new `user_data` is applied when the instance is recreated for another reason. Do not widen it to `metadata` — that would also ignore `ssh_authorized_keys` changes.

Instance FQDNs come from the VCN Resolver (`<hostname>.<subnet dns_label>.<vcn dns_label>.oraclevcn.com`). `dns_label` is ForceNew on both `oci_core_vcn` and `oci_core_subnet`, so changing it recreates the subnets and both instances.

## Workflow

```bash
terraform init     # first time only (Terraform Cloud backend)
terraform validate # before plan/apply
terraform plan     # review changes
terraform apply    # deploy
```

PRs must include `terraform plan` output. `main` is protected; all changes via PR.

## GitHub OpenCode

Workflow `.github/workflows/opencode.yml` triggers on `/oc` or `/opencode` comments in PRs/issues.
