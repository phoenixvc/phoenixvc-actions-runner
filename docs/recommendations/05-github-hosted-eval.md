# Recommendation 05: GitHub-Hosted Evaluation

| Metadata | Value |
|----------|-------|
| **Priority** | Low |
| **Effort** | Low |
| **Impact** | Low (Maintenance reduction) |

## Problem Statement
The current self-hosted VMSS strategy exists to satisfy requirements for Azure VNet access (KeyVault, Private DBs) and to avoid the costs of high-powered GitHub-hosted runners. However, GitHub's own hosted fleet is evolving.

## Detailed Implementation Steps

### 1. Identify "Public-Only" Workflows
Browse the GitHub repositories under `phoenixvc`. Identify any workflows that **do not** require access to the Azure VNet (e.g., simple unit tests, linters, or documentation builds).

### 2. Proof of Concept: Large Runners
For CPU-intensive jobs, try using a **GitHub-hosted Large Runner** with a custom image.
- **Path**: `Organization Settings` > `Actions` > `Runners` > `New runner` > `New GitHub-hosted runner`.
- Compare the price-per-minute of a 4-core GitHub runner vs. your Azure B1s/B2s costs.

### 3. Move Non-Network Jobs
If GitHub-hosted is comparable in price for non-network-dependent jobs, move those repositories over to the `ubuntu-latest` fleet.
- This reduces the scale-out pressure on your `azure-vnet` scale set, leaving those instances available for critical infrastructure jobs.

## Expected Outcome
- Simplified runner management for basic repos.
- Reduced Azure compute costs.
