# OIDC Authentication for Azure

This document explains the OpenID Connect (OIDC) authentication setup used by the GitHub Actions workflows in this repository to communicate with Azure without needing static secrets.

## Overview

Instead of storing a client secret or service principal key in GitHub Secrets, we use **Federated Identity Credentials**. This allows GitHub Actions to request a short-lived token from Azure AD (Entra ID) by proving its identity based on the repository name and branch.

## Setup Components

### 1. Azure AD Application
A Service Principal (App Registration) exists in Azure with the required permissions to manage resources (e.g., VMSS, Networking).

### 2. Federated Identity Credentials
We configure "trust" between Azure and GitHub for specific branches. 
- **Example Subject**: `repo:phoenixvc/phoenixvc-actions-runner:ref:refs/heads/dev`
- This ensures only the `dev` branch in the `phoenixvc-actions-runner` repo can assume the role.

### 3. Automation Scripts
- [add-github-oidc-dev.ps1](../scripts/add-github-oidc-dev.ps1): A PowerShell script to automate the creation of the federated credential for the `dev` branch.
- [federated-credential.json](../federated-credential.json): The JSON payload template for the Azure CLI.

## Usage in Workflows

In your GitHub Action YAML files, you use the `azure/login` action with OIDC:

```yaml
- name: Login to Azure
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.ARM_CLIENT_ID }}
    tenant-id: ${{ secrets.ARM_TENANT_ID }}
    subscription-id: ${{ secrets.ARM_SUBSCRIPTION_ID }}
```

**Note**: You must ensure the workflow has the following permission:
```yaml
permissions:
  id-token: write
  contents: read
```

## Maintenance
If you create new long-lived branches (e.g., `staging`) and want to use Terraform from them, you must run the `add-github-oidc-dev.ps1` script (or equivalent) to add a new federated identity credential for that branch's `ref`.
