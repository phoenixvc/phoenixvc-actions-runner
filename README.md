# phoenixvc-actions-runner

Self-hosted GitHub Actions runner infrastructure for phoenixvc org and JustAGhosT personal account. Ephemeral VMSS for phoenixvc, persistent runner for JustAGhosT, shared listener VM on Azure.

## Prerequisites

- HouseOfVeritas (or equivalent) deployed with runner subnet and Key Vault/Storage firewall rules
- `runner_subnet_id` from HouseOfVeritas: `cd HouseOfVeritas/terraform/environments/production && terraform output -raw runner_subnet_id`

## Quick Start

```bash
./scripts/setup-self-hosted-runner.sh
```

See [docs/setup.md](docs/setup.md) for full setup.

## Structure

``` text
terraform/     # Listener VM + VMSS (deploys into existing subnet)
scripts/       # Install scripts for listener VM
docs/          # Setup guide
```

## Cost

~$16–20/month (listener B1ms + VMSS pay-per-use)
