# Recommendation 01: Custom Machine Images (Gold Images)

| Metadata | Value |
|----------|-------|
| **Priority** | High |
| **Effort** | Medium |
| **Impact** | High (Primary bottleneck: Cold Start) |

## Problem Statement
The current `cloud-init.yaml` process installs dependencies (Docker, Node, Azure CLI, Terraform) on every single VM boot. This results in a "cold start" delay of 3–5 minutes before the runner can accept jobs.

## Detailed Implementation Steps

### 1. Create a "Template" VM
1. Launch a temporary Azure VM using the base Ubuntu 22.04 LTS image in the same Resource Group.
2. Manually run the installation commands from `terraform/cloud-init.yaml`:
   ```bash
   # Install Docker, Node, Azure CLI, Terraform, and Runner binaries
   # (Refer to the bash commands in cloud-init.yaml)
   ```
3. Optimize the image:
   - Run `sudo apt-get clean` to reduce size.
   - Remove any temporary secrets or SSH keys.
   - Run `waagent -deprovision+user` to generalize the VM for imaging.

### 2. Capture the Image
1. In the Azure Portal, select **Capture** on the Template VM.
2. Create an **Azure Compute Gallery** (if one doesn't exist).
3. Create an **Image Definition** (e.g., `pvc-runner-ubuntu`).
4. Save the image version.

### 3. Update Terraform Configuration
Modify `terraform/main.tf` to reference the new image ID instead of the Canonical publisher.

```hcl
# In azurerm_linux_virtual_machine.listener and azurerm_linux_virtual_machine_scale_set.phoenixvc
# Replace source_image_reference with source_image_id:

source_image_id = "/subscriptions/.../providers/Microsoft.Compute/galleries/.../images/..."
```

### 4. Simplify Cloud-Init
Remove the heavy installation steps from `cloud-init.yaml` and only keep runtime configurations (like setting up the swap file or starting scripts).

## Expected Outcome
- **Deployment Speed**: Runner ready in <30 seconds.
- **Reliability**: Eliminates failures caused by external package repository outages (apt, nodesource, hashicorp) during boot.
