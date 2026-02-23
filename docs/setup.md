# Self-Hosted Runner Setup (phoenixvc + JustAGhosT)

Dual runner setup: phoenixvc org (ephemeral scale set) + JustAGhosT personal (persistent runner), shared Azure infrastructure.

## Quick Start

```bash
./scripts/setup-self-hosted-runner.sh
```

---

## Phase 1: GitHub Setup

### 1.1 Create GitHub App for phoenixvc

1. Go to **phoenixvc** org → **Settings** → **Developer settings** → **GitHub Apps** → **New GitHub App**
2. **Name:** `phoenixvc-actions-runner`
3. **Description** (copy-paste):

   ```
   Manages ephemeral GitHub Actions runners for phoenixvc org. Scales VMSS based on workflow demand. Used by Scale Set Client for Key Vault and Storage access from Azure VNet.
   ```

4. **Homepage URL:** `https://github.com/phoenixvc`
5. **Permissions** → **Organization permissions** → **Administration:** Read and write
6. **Where can this GitHub App be installed?** → Only on this account
7. **Webhook:** Leave URL blank and secret empty. The Scale Set Client uses API polling, not webhooks.
8. Click **Create GitHub App**
9. **Generate a private key** → Download the `.pem` file
10. **Install App** → Install on phoenixvc org
11. Note: **App ID**, **Installation ID** (from the install URL or App settings)

### 1.2 Create Runner Group in phoenixvc

1. phoenixvc → **Settings** → **Actions** → **Runners** → **Runner groups**
2. **New runner group:** `azure-vnet`
3. **Visibility:** All repositories (or select specific repos)
4. Add repositories that should use the runner

### 1.3 Create PAT for JustAGhosT

1. GitHub → **JustAGhosT** profile → **Settings** → **Developer settings** → **Personal access tokens**
2. **Generate new token (classic)** with scopes: `repo`, `workflow`
3. Store in Azure Key Vault or another secrets manager

---

## Phase 2: Terraform (Runner Infrastructure)

### 2.1 Prerequisites

- HouseOfVeritas (or equivalent) deployed with runner subnet
- Runner subnet added to Key Vault and Storage firewall in HouseOfVeritas

### 2.2 Get Runner Subnet ID

```bash
cd ../HouseOfVeritas/terraform/environments/production
terraform output -raw runner_subnet_id
```

### 2.3 Apply

```bash
cd phoenixvc-actions-runner/terraform
terraform init
terraform plan \
  -var="runner_subnet_id=$(cd ../../HouseOfVeritas/terraform/environments/production && terraform output -raw runner_subnet_id)" \
  -var="ssh_public_key=$RUNNER_SSH_PUBLIC_KEY" \
  -var="resource_group_name=nl-prod-hov-rg-san" \
  -var="location=South Africa North"
terraform apply ...
```

### 2.4 Get Listener Private IP

```bash
terraform output -raw listener_private_ip
```

---

## Phase 3: Install on Listener VM

### 3.1 SSH to Listener

```bash
ssh azureuser@<listener-private-ip>
```

(Use Azure Bastion or VPN if no direct access.)

### 3.2 Place GitHub App Key

```bash
sudo mkdir -p /etc/phoenixvc-runner
# Copy your .pem file content to /etc/phoenixvc-runner/key.pem
sudo chmod 600 /etc/phoenixvc-runner/key.pem
```

### 3.3 Install Scale Set Client (phoenixvc)

```bash
export GITHUB_APP_ID="<your-app-id>"
export GITHUB_INSTALLATION_ID="<your-installation-id>"
export GITHUB_APP_KEY_PATH="/etc/phoenixvc-runner/key.pem"

./install-scale-set-client.sh
sudo systemctl enable --now phoenixvc-scale-set
```

### 3.4 Install Persistent Runner (JustAGhosT)

1. Go to **JustAGhosT** → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Copy the registration token
3. On listener VM:

```bash
export GITHUB_RUNNER_TOKEN="<token-from-github-ui>"
./install-persistent-runner.sh
```

---

## Phase 4: Workflow Updates

### phoenixvc repos

```yaml
jobs:
  build:
    runs-on: [azure-vnet]
```

### JustAGhosT repos

```yaml
jobs:
  build:
    runs-on: [self-hosted, azure-vnet-ghost]
```

---

## Cost

| Item | Monthly |
|------|---------|
| Listener VM (B1ms) | ~$15 |
| VMSS (pay-per-use) | ~$1–5 |
| **Total** | **~$16–20** |

---

## Troubleshooting

- **Scale Set Client not scaling:** Check VMSS name in config; ensure Azure CLI/identity can scale VMSS.
- **Persistent runner offline:** `sudo ./svc.sh status` in `/opt/gh-runner-justaghost`.
- **VMSS instances not getting JIT config:** Implement HTTP endpoint in Scale Set Client wrapper; update `vmss-startup.sh` `JIT_ENDPOINT`.
