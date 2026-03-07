# Self-Hosted Runner Setup (phoenixvc + JustAGhosT)

Dual runner setup: phoenixvc org (ephemeral scale set) + JustAGhosT
personal (persistent runner), shared Azure infrastructure.

## Quick Start

```bash
./scripts/setup-self-hosted-runner.sh
```

---

## Phase 1: GitHub Setup

### 1.1 Create GitHub App for phoenixvc

1. Go to **phoenixvc** org → **Settings** → **Developer settings** →
   **GitHub Apps** → **New GitHub App**
2. **Name:** `phoenixvc-actions-runner`
3. **Description** (copy-paste):

   ```text
   Manages ephemeral GitHub Actions runners for phoenixvc org.
   Scales VMSS based on workflow demand. Used by Scale Set Client
   for Key Vault and Storage access from Azure VNet.
   ```

4. **Homepage URL:** `https://github.com/phoenixvc`
5. **Permissions** → **Organization permissions:**
   - **Administration:** Read and write
   - **Self-hosted runners:** Read and write
6. **Where can this GitHub App be installed?** → Only on this account
7. **Webhook:** Leave URL blank and secret empty. The Scale Set Client
   uses API polling, not webhooks.
8. Click **Create GitHub App**
9. **Generate a private key** → Download the `.pem` file
10. **Install App** → Install on phoenixvc org
11. Note: **App ID**, **Installation ID** (from the install URL or
    App settings)

### 1.2 Create Runner Group in phoenixvc

1. phoenixvc → **Settings** → **Actions** → **Runners** →
   **Runner groups**
2. **New runner group:** `azure-vnet`
3. **Visibility:** All repositories (or select specific repos)
4. Add repositories that should use the runner

### 1.3 Create PAT for JustAGhosT

1. GitHub → **JustAGhosT** profile → **Settings** →
   **Developer settings** → **Personal access tokens**
2. **Generate new token (classic)** with scopes: `repo`, `workflow`
3. Store in Azure Key Vault or another secrets manager

---

## Phase 2: Terraform (Runner Infrastructure)

### 2.1 Prerequisites

- HouseOfVeritas (or equivalent) deployed with runner subnet
- Runner subnet added to Key Vault and Storage firewall in
  HouseOfVeritas

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
  -var="resource_group_name=pvc-prod-actionsrunner-rg-san" \
  -var="location=South Africa North"
terraform apply ...
```

### 2.4 Get Listener Private IP

```bash
terraform output -raw listener_private_ip
```

### 2.5 GitHub Actions secrets and variables for Runner Terraform

The `Runner Terraform` GitHub Actions workflow expects Azure credentials
and runner settings to be provided via **Secrets** and **Variables** on
the `phoenixvc/phoenixvc-actions-runner` repo.

Go to: **Repository** → **Settings** → **Secrets and variables** →
**Actions**.

#### 2.5.1 Azure authentication (Secrets)

These are standard ARM env vars for Terraform on Azure:

- `ARM_CLIENT_ID`
- `ARM_CLIENT_SECRET`
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID`

Typical way to obtain them (service principal with client secret):

1. In Azure, create an App registration (or reuse an existing
   Terraform SP) with access to the subscription/resource group.
2. Note the following from the App registration:
   - **Application (client) ID** → `ARM_CLIENT_ID`
   - **Directory (tenant) ID** → `ARM_TENANT_ID`
3. Create a client secret under **Certificates & secrets** and copy
   the value → `ARM_CLIENT_SECRET`.
4. In Azure Portal or CLI, get the Subscription ID →
   `ARM_SUBSCRIPTION_ID`.

Alternatively, using Azure CLI:

```bash
az ad sp create-for-rbac \
  --name phoenixvc-actions-runner-terraform \
  --role "Contributor" \
  --scopes /subscriptions/<subscription-id>/resourceGroups/<runner-rg-name>
```

Map the JSON output fields to the four secrets above. For production,
prefer a least-privilege approach instead of full `Contributor`:

- Create a custom role scoped to the runner resource group with only
  the actions your Terraform actually uses (e.g., VM, NIC, subnet,
  and managed identity operations), or
- Combine built-in roles such as `Virtual Machine Contributor`,
  `Network Contributor`, and `Storage Blob Data Contributor` if your
  modules require them.

Then use that narrower role name in `--role` with the same scoped
`/subscriptions/.../resourceGroups/<runner-rg-name>`.

#### 2.5.2 Runner network and SSH (Secrets)

Additional secrets for the runner infra:

- `RUNNER_SUBNET_ID`
- `RUNNER_SSH_PUBLIC_KEY`

**`RUNNER_SUBNET_ID`**

- From the HouseOfVeritas Terraform environment (or equivalent):

  ```bash
  cd ../HouseOfVeritas/terraform/environments/production
  terraform output -raw runner_subnet_id
  ```

- Copy the output value into the `RUNNER_SUBNET_ID` secret.

**`RUNNER_SSH_PUBLIC_KEY`**

- Use an existing SSH key, or generate a new one on your workstation:

  ```bash
  ssh-keygen -t ed25519 -C "phoenixvc-runner" -f ~/.ssh/phoenixvc-runner
  ```

- Put the **public** key content (the `.pub` file) into the
  `RUNNER_SSH_PUBLIC_KEY` secret.
- Never store the private key in GitHub or this repo.

#### 2.5.3 Runner resource group and location (Variables)

Configure these as **Variables** (not secrets):

- `RUNNER_RESOURCE_GROUP_NAME`
- `RUNNER_LOCATION`

##### Resource group naming convention

- For runner infra, use:

  ```text
  pvc-prod-<short-project-name>-rg-san
  ```

- Example:

  ```text
  pvc-prod-actionsrunner-rg-san
  ```

- This follows the pattern:
  `pvc-prod-{projectname shortened}-{resource type}-location`, where:
  - environment = `prod`
  - resource type suffix = `rg`
  - location suffix = `san` (South Africa North)

Set `RUNNER_RESOURCE_GROUP_NAME` to the actual resource group name you
created for runner infra.

##### Location

- Default region for this setup is **South Africa North**.
- Set:

  ```text
  RUNNER_LOCATION = South Africa North
  ```

Once all of the above are configured, you can trigger the
`Runner Terraform` workflow from **Actions → Runner Terraform →
Run workflow**, starting with `apply = false` (plan only), then
`apply = true` when you are ready to apply.

---

## Phase 3: Install on Listener VM

### 3.1 SSH to Listener

```bash
ssh azureuser@<listener-private-ip>
```

(Use Azure Bastion or VPN if no direct access.)

### 3.2 Place GitHub App Key

From your workstation, deploy the key using `write-key.sh`:

```bash
B64KEY=$(base64 -w0 < /path/to/phoenixvc-actions-runner.private-key.pem)

az vm run-command invoke \
  -g <runner-rg-name> -n <listener-vm-name> \
  --command-id RunShellScript \
  --script "export B64KEY='$B64KEY' && bash -s" \
  --scripts @terraform/write-key.sh
```

Or, if SSH'd into the listener VM directly:

```bash
export B64KEY="$(base64 -w0 < /path/to/key.pem)"
./write-key.sh
```

### 3.3 Install Scale Set Client (phoenixvc)

```bash
export GITHUB_APP_ID="<your-app-id>"
export GITHUB_INSTALLATION_ID="<your-installation-id>"
export GITHUB_APP_KEY_PATH="/etc/phoenixvc-runner/key.pem"

./install-scale-set-client.sh
sudo systemctl enable --now phoenixvc-scale-set
```

### 3.4 Install Persistent Runner(s) (JustAGhosT)

Runner configs live in `runners.d/*.conf`. Each file defines one
runner registration (repo URL, name, labels).

#### Install all runners

1. Get a registration token from **each repo** → **Settings** →
   **Actions** → **Runners** → **New self-hosted runner**
2. On listener VM:

```bash
# If all repos share the same token (same owner):
export GITHUB_RUNNER_TOKEN="<token>"
./scripts/install-all-runners.sh
```

#### Install a single runner

```bash
export GITHUB_RUNNER_TOKEN="<token-from-repo-settings>"
./scripts/install-persistent-runner.sh runners.d/agentkit-forge.conf
```

#### Add a new repo

Create a new conf file in `runners.d/`:

```bash
cat > runners.d/my-repo.conf << 'EOF'
GITHUB_REPO_URL=https://github.com/JustAGhosT/my-repo
RUNNER_NAME=my-repo-linux
RUNNER_LABELS=self-hosted,Linux,X64,azure-vnet-ghost
EOF
```

Then install it with `install-persistent-runner.sh runners.d/my-repo.conf`.

### 3.5 Install Windows Runner (JustAGhosT/agentkit-forge)

For repos that need a **Windows** runner (e.g., `agentkit-forge`):

1. Go to **JustAGhosT/agentkit-forge** → **Settings** → **Actions** →
   **Runners** → **New self-hosted runner**
2. Select **Windows** / **x64** and copy the registration token
3. On the target Windows machine, open an **elevated PowerShell**:

```powershell
$env:GITHUB_RUNNER_TOKEN = "<token-from-github-ui>"
.\scripts\setup-windows-runner.ps1
```

The script will:

- Create `\actions-runner` at the drive root (recommended by GitHub to
  avoid long-path and permission issues on Windows)
- Download and verify runner **v2.332.0**
- Configure the runner for `JustAGhosT/agentkit-forge`
- Install and start it as a Windows service

You can override defaults with parameters:

```powershell
.\scripts\setup-windows-runner.ps1 `
  -RunnerName "my-custom-name" `
  -RunnerDir "D:\actions-runner" `
  -Labels "self-hosted,windows,x64,gpu"
```

Check status anytime: `\actions-runner\svc.cmd status`

---

## Phase 4: Workflow Updates

### phoenixvc repos

```yaml
jobs:
  build:
    runs-on: [azure-vnet]
```

### JustAGhosT repos (Linux)

```yaml
jobs:
  build:
    runs-on: [self-hosted, azure-vnet-ghost]
```

### JustAGhosT/agentkit-forge (Windows)

```yaml
jobs:
  build:
    runs-on: self-hosted
```

---

## Using the runner from JustAGhosT repos (cross-account)

The runner infrastructure lives in **phoenixvc** Azure, but the persistent
runner is registered to **JustAGhosT**. Repos under JustAGhosT (e.g.
HouseOfVeritas) can use it.

### Repo setup (no changes to this repo)

1. **Runner registration:** Each repo needs its own runner registered at
   the repo level (Phase 3.4). Add a `.conf` file in `runners.d/` for
   each repo. Verify at **repo** → **Settings** → **Actions** →
   **Runners**.

2. **No runner sharing needed:** Since runners are registered per-repo,
   there is no "repository access" to configure. Each repo's runner
   only picks up jobs from that repo.

3. **Workflow:** In the consuming repo, use
   `runs-on: [self-hosted, azure-vnet-ghost]` for jobs that need VNet access
   (Terraform, Key Vault, Storage).

### Why cross-account works

- The runner VM is in phoenixvc Azure (phoenixvc-actions-runner Terraform).
- Each runner process is registered at the **repo level** (e.g.,
  `config.sh --url https://github.com/JustAGhosT/agentkit-forge`).
  Personal accounts don't support account-level runners — only orgs do.
- GitHub routes jobs to the runner when workflow `runs-on:` labels match
  the runner's labels (e.g., `[self-hosted, azure-vnet-ghost]`).

---

## Cost

| Item               | Monthly       |
| ------------------ | ------------- |
| Listener VM (B2s)  | ~R560         |
| VMSS (pay-per-use) | ~R20–90       |
| **Total**          | **~R580–650** |

---

## Troubleshooting

- **Scale Set Client not scaling:** Check VMSS name in config; ensure
  Azure CLI/identity can scale VMSS.
- **Persistent runner offline:** `sudo /opt/gh-runner-<name>/svc.sh status`
  (directory matches `RUNNER_NAME` from the `.conf` file).
- **VMSS instances not getting JIT config:** Implement HTTP endpoint in
  Scale Set Client wrapper; update `vmss-startup.sh` `JIT_ENDPOINT`.
- **`Resource not accessible by integration` (403):** Ensure the GitHub
  App has **Self-hosted runners: Read and write** permission under
  Organization permissions.
- **`invalid key: Key must be a PEM encoded PKCS1 or PKCS8 key`:** The
  `dockerscaleset` binary expects PEM *content* as the
  `--app-private-key` argument, not a file path. Use a wrapper script
  that reads the key file and passes the content.

---

## Dependency updates with Renovate

This repo includes a basic `renovate.json` configuration to keep
Terraform providers and GitHub Actions up to date in a controlled way.

- Managers enabled:
  - `terraform` (for `./terraform`)
  - `github-actions` (for `.github/workflows`)
- Updates are grouped into logical PRs (Terraform providers, GitHub
  Actions) and scheduled to run during off-hours in the
  `Africa/Johannesburg` timezone.

To use Renovate:

1. Install/configure the Renovate bot for the `phoenixvc` GitHub
   organization (either the hosted Renovate GitHub App or your
   self-hosted runner, per org standards).
2. Ensure the bot has access to this repository and respects the
   org-wide Renovate onboarding settings.
3. Review and merge the initial Renovate onboarding PR if one is
   opened, then monitor subsequent dependency bump PRs as part of
   normal review flow.

You can further tune `renovate.json` to add labels, reviewers, or
additional package rules once the baseline is stable.
