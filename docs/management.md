# Runner Infrastructure Management

This guide covers day-to-day operations, troubleshooting, and maintenance for the `phoenixvc-actions-runner` infrastructure.

## Operational Overview

The infrastructure consists of:
1.  **Listener VM**: A persistent Azure VM that polls GitHub for jobs and manages the VMSS.
2.  **VMSS (Scale Set)**: Ephemeral VMs that boot up to run specific GitHub Action jobs.

## How to Use These Runners in Workflows

To direct a job to your private runner infrastructure, you must modify the workflow YAML file in the repository (located at `.github/workflows/*.yml`).

### Targeting the Scale Sets (Recommended)
Set the `runs-on` property to the label associated with your Scale Set Client:

```yaml
jobs:
  build:
    runs-on: self-hosted  # or your specific label like 'azure-vnet'
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on private Azure infrastructure"
```

### Targeting Persistent Runners
If you are using a specific persistent runner for a repository:

```yaml
jobs:
  specialized-task:
    runs-on: [self-hosted, agentkit-forge] # Using multiple labels to target a specific instance
    steps:
      - run: echo "Running on the persistent AgentKit machine"
```

> [!IMPORTANT]
> If you specify `runs-on: self-hosted` but the repository or workflow does not have access (see [Adding or Removing Repositories](#adding-or-removing-repositories)), the job will **not** fall back to GitHub-hosted runners. It will **fail** with a "No runner found" error.

## Adding or Removing Repositories

The method for adding or removing repository access depends on the type of runner.

### 1. Organization Scale Sets (phoenixvc)

These runners are available to multiple repositories based on **Runner Group** configuration.

- **Repository Access Control**:
  1. Go to `Organization Settings` > `Actions` > `Runner groups`.
  2. Select the group associated with the scale set (e.g., `azure-vnet`).
  3. Under **Repository access**, select **Selected repositories** to restrict access to a subset of the org.
- **Workflow Access Control** (Advanced):
  1. In the same **Runner Group** settings, look for **Workflow access**.
  2. You can restrict the group to only be used by:
    - **All workflows** (Default).
    - **Selected workflows**: Specify the repository and the specific workflow path (e.g., `.github/workflows/deploy.yml`).
  3. *Use Case*: Only let high-security deployment workflows run on your private runners, while allowing regular CI to use GitHub-hosted runners.

### GitHub-Hosted Fallback Behavior

It is important to understand how GitHub resolves these restrictions:

- **No Automatic Fallback**: If a workflow specifies `runs-on: [self-hosted, ...]` but is **not authorized** to use the Runner Group (either by Repository or Workflow restriction), the job will **fail** with a "No runner found" error. It will **not** automatically switch to a GitHub-hosted runner (like `ubuntu-latest`).
- **Co-existence Strategy**: If you want "rest picked up by GH," you must architect your workflows accordingly:
    - **Authorized Workflows**: Set `runs-on: [self-hosted, ...]` for jobs needing your private Azure environment.
    - **Rest of Workflows**: Set `runs-on: ubuntu-latest` for jobs (linters, unit tests) that don't need private access. These will *always* be picked up by GitHub-hosted runners.
- **To "Default" to GitHub**: Simply remove the `self-hosted` labels from the standard workflows in those repositories.

---

### 2. Persistent Runners (JustAGhosT / Custom)

These runners are registered directly to a single repository.

- **To Add a New Repo Runner**:
    1. Create a new configuration file in [runners.d/](runners.d/) (e.g., `new-repo.conf`).
    2. Obtain a runner token from `https://github.com/<owner>/<repo>/settings/actions/runners/new`.
    3. Run the installation script:

        ```bash
        export GITHUB_RUNNER_TOKEN="<new-token>"
        ./scripts/install-persistent-runner.sh runners.d/new-repo.conf
        ```

- **To Remove a Repo Runner**:
    1. SSH to the VM hosting the runner.
    2. Navigate to the runner directory (defined in `.conf` as `RUNNER_DIR`).
    3. Stop and uninstall the service:

        ```bash
        sudo ./svc.sh stop
        sudo ./svc.sh uninstall
        ```

    4. Remove the config file from `runners.d/` to prevent accidental re-installation.

---

## Maintenance & Monitoring

### 1. Scaling the Infrastructure

You can manually scale the runners using GitHub Actions or Terraform:

- **GitHub Workflow**: Use the `Scale Runners` workflow in the `.github/workflows/` directory.
- **Terraform**: Update `vmss_min_capacity` or `vmss_max_capacity` in `terraform/variables.tf` and run `terraform apply`.

### 2. Health Checks

- **Listener Status**: SSH to the listener VM and run `sudo systemctl status phoenixvc-scale-set`.
- **Service Logs**: View logs with `sudo journalctl -u phoenixvc-scale-set -f`.
- **Azure Portal**: Check the "Instances" tab in the `${environment}-runner-phoenixvc-vmss` to see active jobs.

### 3. Updating Runner Version

1. Modify `runner-version.env` in the root directory.
2. The listener VM will require a restart or re-run of `install-scale-set-client.sh`.
3. *Note*: If using [Custom Images](recommendations/01-custom-images.md), you must rebuild the image with the new version.

## Troubleshooting

| Issue | Potential Cause | Solution |
| :--- | :--- | :--- |
| **Jobs stuck in "Queued"** | Listener service down | Restart `phoenixvc-scale-set` service. |
| **VMSS failing to scale** | vCPU Quota hit | Verify regional core quota in Azure Portal. |
| **OIDC Login Failures** | Federated Credential missing | Run `scripts/add-github-oidc-dev.ps1` for the current branch. |
| **"No Space Left on Device"** | Docker cache full | SSH to the instances or rebuild image to clear `/var/lib/docker`. |

## Future Roadmap & Schedule

- **Monthly**: Review vCPU usage and adjust `vmss_max_capacity`.
- **Quarterly**: Cycle the Listener VM SSH keys and GitHub App private keys.
- **As Needed**: Update the `ubuntu_image_version` in Terraform to pull the latest security patches.
- **Strategic**: Refer to the [Project Roadmap](roadmap.md) for long-term improvements.
