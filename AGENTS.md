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

Required vars: `tenancy_ocid`, `user_ocid`, `fingerprint`, `region` (default `ap-osaka-1`), `private_key`, `adb_admin_password`.

## Tools

Managed via `mise` (`mise.toml`): `oci` and `terraform` (both `latest`).

## Deployed resources (Always Free limits)

| Resource | Status |
|----------|--------|
| VM.Standard.E2.1.Micro × 2 | ✅ Deployed (max 2) |
| Object Storage 20GB | ✅ Deployed (max 20GB) |
| Autonomous Database | ✅ Deployed (default password in `variables.tf`) |
| VM.Standard.A1.Flex (Arm) | ❌ Commented out — capacity issues in ap-osaka-1 |
| Block Volume, Load Balancer | Not created yet |

SSH key is hardcoded in `main.tf:181` metadata. Update there to change.

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
