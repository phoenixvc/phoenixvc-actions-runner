# Recommendation 03: Security Hardening

| Metadata | Value |
|----------|-------|
| **Priority** | Medium |
| **Effort** | Medium |
| **Impact** | High (Long-term stability and compliance) |

## Problem Statement
The listener VM and VMSS runners are standard Linux instances. Over time, unpatched vulnerabilities can pose a risk to the Azure environment and the organization's supply chain.

## Detailed Implementation Steps

### 1. Enable Azure Update Manager
1. In the Azure Portal, search for **Update Manager**.
2. Select the `listener` VM and the VMSS.
3. Enable **Periodic Assessment** for updates.
4. Configure an **Update Schedule** (e.g., every Tuesday at 2 AM) to automatically install critical and security patches.

### 2. Network Security Group (NSG) Hardening
Audit the `runner-nsg` defined in `terraform/main.tf`.
- **Inbound**: Ensure `allow-ssh-admin` (Port 22) is strictly limited to a trusted IP or is disabled entirely, relying on **Azure Bastion** for access.
- **Outbound**: By default, runners have full outbound access. Consider using a **Network Virtual Appliance (NVA)** or **Azure Firewall** if you need to restrict runners to only communicate with `github.com` and required package mirrors.

### 3. Automated Image Rotation
If using **Recommendation 01 (Custom Images)**, schedule a monthly rebuild of the image.
- This ensures that a "fresh" runner already has the latest security updates baked in, rather than downloading them during every boot (which re-introduces cold-start latency).

## Expected Outcome
- Compliance with security best practices.
- Reduced risk of lateral movement if a CI job is compromised.
