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
.github/workflows/  # Runner Terraform CI (OIDC, plan/apply), healthcheck, scale, test alerts
.github/actions/    # Reusable composite actions (cost guard, VMSS cap)
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

## Workflows

- Runner Terraform: plans/applies infra via OIDC, pinned actions.
- Runner Health Check: checks service liveness and restarts stalled listeners when jobs are queued.
- Scale Runners: manual scale and scheduled auto-scale with budget guard and dynamic autoscale cap retrieval.
- Test Alerts: sends test notifications and prints estimated monthly costs (current/minimum).
- OIDC Claims Check (dev): prints OIDC token claims (subject, audience, issuer) to verify federated identity setup for branch refs.

## Alerts

- Listener VM unavailability (>30 min): Sev 1 metric alert to action group.
- VMSS updates (capacity and writes): Activity Log alert to action group.
- Budget guard: test notification when estimated monthly cost exceeds configurable budget.

## Cost

- Rates are configurable via repository variables:
  - `VMSS_RATE_USD_B1S` (default 0.0104)
  - `LISTENER_RATE_USD_B2S` (default 0.0416)
  - `ZAR_PER_USD` (default 19)
  - `MONTHLY_BUDGET_ZAR` (default 1000)
- Estimates use 720 hours/month and include the listener VM + VMSS capacity.

## CI on dev branch

- Configure Microsoft Entra federated identity credential for the dev branch ref:
  - Subject: `repo:phoenixvc/phoenixvc-actions-runner:ref:refs/heads/dev`
  - Issuer: `https://token.actions.githubusercontent.com`
  - Audience: `api://AzureADTokenExchange`
- Optional fallback: add `AZURE_CREDENTIALS` secret (JSON: clientId, tenantId, subscriptionId, clientSecret) enabling Service Principal login when OIDC is not yet configured.
