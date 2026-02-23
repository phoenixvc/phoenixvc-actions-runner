# phoenixvc-actions-runner

Self-hosted GitHub Actions runner infrastructure for the **phoenixvc** org and **JustAGhosT** personal account. Ephemeral VMSS for phoenixvc, persistent runner for JustAGhosT, shared listener VM on Azure.

## Prerequisites

- HouseOfVeritas (or equivalent) deployed with runner subnet
- Runner subnet added to Key Vault and Storage firewall rules
- GitHub App (`phoenixvc-actions-runner`) with **Administration** and **Self-hosted runners** Read & Write permissions

## Quick Start

```bash
./scripts/setup-self-hosted-runner.sh
```

See [docs/setup.md](docs/setup.md) for full setup.

## Structure

```text
.github/workflows/  # Runner Terraform CI (OIDC, plan/apply)
terraform/          # Listener VM + VMSS + NSG (deploys into existing subnet)
scripts/            # Install scripts for listener VM
docs/               # Setup guide
renovate.json       # Dependency update config (Terraform + GH Actions)
```

## Security

- **Never commit private keys or secrets** to this repo.
- The `.gitignore` blocks `*.pem`, `*.key`, and `*.b64` files.
- Use `terraform/write-key.sh` with the `B64KEY` environment variable to deploy the GitHub App private key to the listener VM.
- SSH access to the listener VM is restricted via the `admin_cidr` Terraform variable (default: Azure health probe only).

## Cost

~R300-370/month (listener B1ms + VMSS pay-per-use)
