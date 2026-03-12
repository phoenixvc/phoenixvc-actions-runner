# Actions Runner Controller (ARC) vs. Current VMSS Setup

This document compares the current Azure Virtual Machine Scale Set (VMSS) runner infrastructure with the [GitHub Actions Runner Controller (ARC)](https://docs.github.com/en/actions/concepts/runners/actions-runner-controller).

## Is phoenixvc using ARC?

**Technically, No.** The `phoenixvc` setup does not use the Kubernetes-native "Controller" (ARC).

**However**, the `phoenixvc` setup uses the **same underlying protocol** as ARC. 
- ARC (in Scale Set mode) uses a protocol called "Action Scale Sets".
- The `phoenixvc` setup uses a Go-based client (`scaleset-client`) cloned from `https://github.com/actions/scaleset.git`.
- This client is the **non-Kubernetes implementation** of the ARC listener logic. It provides the same benefits (ephemeral runners, direct scale-out) but runs on standard VMs/VMSS instead of in a Kubernetes cluster.

## Comparison Table

| Feature | Current VMSS Setup | ARC (Actions Runner Controller) |
|---------|-------------------|--------------------------------|
| **Host Platform** | Azure VMSS (Virtual Machines) | Kubernetes (AKS/EKS/GKE) |
| **Complexity** | Low (Manage VMs/Terraform) | High (Maintain Kubernetes) |
| **Scaling** | VMSS instances (Warm/Cold) | Kubernetes Pods (Fast) |
| **Cost** | Fixed VM costs + Scale out | Cluster overhead + Pod usage |
| **Isolation** | Strong (Individual VMs) | Container-level (Shared node) |
| **Maintenance** | Minimal (OS updates) | High (K8s versioning, ARC updates) |

## Should we switch to ARC?

**Current Recommendation: NO.**

### 1. Simple is Better
The current setup is highly efficient and already provides the core benefit of ARC (ephemeral, auto-scaling runners) without the operational overhead of a Kubernetes cluster dedicated to CI.

### 2. Budget and Scaling Down
Given the ongoing **Mystira Scaledown Plan** (which involves *reducing* AKS Footprint), moving the runner infrastructure *into* Kubernetes would go against the goal of simplifying the infrastructure and reducing management tasks.

### 3. Isolation
CI runners often perform heavy disk I/O and CPU bursts. Running them on dedicated B1s instances in a VMSS provides better performance isolation than sharing a Kubernetes node where CI jobs might "noisy neighbor" production workloads.

## When to Consider ARC
- If the organization's Kubernetes footprint grows and maintenance becomes automated.
- If we need specialized containerized runners with different environments (e.g., specific Linux distros) within the same scale set.
- If we want to utilize "Job-level" pod scaling where every job gets a clean container instantly.

## Summary
You are currently using the **modern "Scale Set" logic** that powers ARC, but optimized for a **leaner, VM-based infrastructure**. This is a highly robust "Goldilocks" setup for an organization of your size.
