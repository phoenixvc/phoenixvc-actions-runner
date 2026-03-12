# Runner Scope and Usage Analysis

This document provides an analysis of the GitHub Actions runner scope and usage for the `phoenixvc` organization and the `JustAGhosT` account.

## Summary of Findings

The infrastructure is split into two distinct management scopes: one optimized for organization-wide ephemeral scaling and another for repository-specific persistent runners.

### 1. phoenixvc Organization (Ephemeral Scale Set)
- **Technology**: GitHub Actions Scale Set Client (Action Scale Sets).
- **Registration**: Registered at the **organization level** (`org: phoenixvc`).
- **Infrastructure**: Azure Virtual Machine Scale Sets (VMSS) with a central listener VM.
- **Repository Scope**: 
    - Because it is registered at the organization level, the runner is **available to all repositories** within the `phoenixvc` organization by default.
    - Actual availability can be further restricted in the GitHub UI (Runner Groups).
    - **Confirmed Usage**: [SCALEDOWN-PLAN.md](../SCALEDOWN-PLAN.md) explicitly references its use for `phoenixvc/mystira.workspace`.
- **Authentication**: Uses a GitHub App (`phoenixvc-actions-runner`) installed on the organization.

### 2. JustAGhosT Account (Persistent Runners)
- **Technology**: Standard self-hosted runner binaries.
- **Registration**: Registered at the **repository level**.
- **Management**: Configured via templates in `runners.d/`.
- **Scope**: Targeted specifically at `JustAGhosT/agentkit-forge`.

## Infrastructure Map

| Component | Scope | Host | Registration Script |
|-----------|-------|------|---------------------|
| **Scale Set Client** | `phoenixvc` Org | Azure VMSS | [install-scale-set-client.sh](../scripts/install-scale-set-client.sh) |
| **Persistent Runner** | `JustAGhosT/agentkit-forge` | Azure VM | [install-persistent-runner.sh](../scripts/install-persistent-runner.sh) |

## How to View Runner Mapping

### GitHub UI (Recommended)

#### **For phoenixvc Organization (Scale Set)**
- **Path**: `Organization Settings` > `Actions` > `Runners`
- **What to look for**:
    - **Runners Tab**: Lists the active scale set runners (usually named with the scale set prefix).
    - **Runner Groups Tab**: This is where you see which repositories can access the runners. 
        - Click on the group (e.g., `Default` or `azure-vnet`).
        - Under **Repository access**, it will show whether it is "All repositories" or a "Selected repositories" list.

#### **For JustAGhosT Accounts (Persistent)**
- **Path**: `Repository` (e.g., [agentkit-forge](https://github.com/JustAGhosT/agentkit-forge)) > `Settings` > `Actions` > `Runners`
- **What to look for**: Runners listed here are registered directly to this repository.
