# Mystira Infrastructure Scaledown Plan

**Date:** 2026-03-09
**Repo:** `phoenixvc/mystira.workspace`
**Terraform Path:** `infra/terraform/environments/{dev,staging,prod}/main.tf`
**Current Core Quota:** 1/10 (SouthAfricaNorth)

## What Was Already Done via Azure CLI

| Action | Status |
|--------|--------|
| `az aks stop` — MYS-DEV-CORE-AKS-SAN (dev) | Done |
| `az aks stop` — MYS-STAGING-CORE-AKS-SAN (staging) | Done |
| `mys-prod-mystira-plan-san` P1v3 → B1 (App Service Plan) | Done |
| `mys-dev-story-asp-san` B2 → B1 (App Service Plan) | Done |
| `mys-prod-core-db` GP_Standard_D4s_v3 → B_Standard_B1ms (PostgreSQL) | Done |
| `mys-prod-core-db` backup_retention 35 → 7 days | Done |
| `mys-prod-core-cache` Standard C2 → C1 (Redis) | Done |
| `mys-prod-mystira-swa-eus2` Standard → Free (Static Web App) | Done |
| `mys-prod-story-swa-eus2` Standard → Free (Static Web App) | Done |

**FAILED (needs alternative):**
| `prod-wus-app-mystira-api-plan` P0v3 → B1 | Failed — West US has zero Basic/Free VM quota. Needs quota request or resource migration. |

---

## Terraform Drift Reconciliation (Required Before Apply)

The Azure CLI changes above modified resources that are **already managed by Terraform** in `phoenixvc/mystira.workspace`. This creates configuration drift — Terraform state still reflects the old values. **No `terraform import` is needed** (the resources are already in state), but you must update the Terraform code to match the new desired state before running `terraform plan/apply`, otherwise Terraform will attempt to revert the CLI changes.

**Procedure:**

1. Update the Terraform code for each affected resource (see sections below) to match the new values
2. Run `terraform plan` in each environment and verify:
   - PostgreSQL shows no change (code matches CLI state)
   - Redis shows no change
   - App Service Plan shows no change
   - Static Web Apps show no change
3. If `terraform plan` shows unexpected changes (e.g. Terraform wants to revert a value), check that the code update matches what the CLI set
4. Only proceed with `terraform apply` once the plan shows **only** the intentional new changes (AKS scaledown, Service Bus migration, etc.) and no drift-reverting changes

**Affected resources and their Terraform addresses:**

| CLI Change | Terraform Resource Address | Azure Resource ID |
| ---------- | -------------------------- | ----------------- |
| PostgreSQL SKU + backup | `module.shared_postgresql.azurerm_postgresql_flexible_server.this` | `/subscriptions/.../resourceGroups/mys-prod-core-rg-san/providers/Microsoft.DBforPostgreSQL/flexibleServers/mys-prod-core-db` |
| Redis capacity | `module.shared_redis.azurerm_redis_cache.this` | `/subscriptions/.../resourceGroups/mys-prod-core-rg-san/providers/Microsoft.Cache/Redis/mys-prod-core-cache` |
| App Service Plan SKU | Look up in mystira-app module | `/subscriptions/.../resourceGroups/mys-prod-mystira-rg-san/providers/Microsoft.Web/serverfarms/mys-prod-mystira-plan-san` |
| Dev Story ASP SKU | Look up in story module | `/subscriptions/.../resourceGroups/mys-dev-story-rg-san/providers/Microsoft.Web/serverfarms/mys-dev-story-asp-san` |
| Static Web App (mystira) | Look up in mystira-app module | `/subscriptions/.../resourceGroups/mys-prod-mystira-rg-san/providers/Microsoft.Web/staticSites/mys-prod-mystira-swa-eus2` |
| Static Web App (story) | `module.story_generator.azurerm_static_web_app.this` | `/subscriptions/.../resourceGroups/mys-prod-story-rg-san/providers/Microsoft.Web/staticSites/mys-prod-story-swa-eus2` |

---

## Terraform Changes Required

All changes below need to be applied in `phoenixvc/mystira.workspace` repo and then `terraform apply` in each environment. The Azure CLI changes above will cause Terraform drift — these Terraform changes bring the code in line with the new state AND add further optimizations.

---

### 1. PROD — `infra/terraform/environments/prod/main.tf`

#### 1.1 AKS Default Node Pool (lines 797-806)
**Current:** 3× Standard_D4s_v3, autoscale 3-10, zones 1-2-3 = **12 cores**
**Target:** 1× Standard_B2s, no autoscale, no zones = **2 cores**
```hcl
# Change these values in the default_node_pool block:
node_count              = 1          # was 3
vm_size                 = "Standard_B2s"  # was "Standard_D4s_v3"
enable_auto_scaling     = false      # was true
# REMOVE: min_count, max_count, zones
```
**Savings:** ~$420/mo (3× D4s_v3 @ $140/mo → 1× B2s @ $15/mo)

#### 1.2 AKS Chain Node Pool (lines 837-860)
**Current:** 3× Standard_D4s_v3, autoscale 3-6, zones 1-2-3 = **12 cores**
**Target:** 1× Standard_B2s, no autoscale, no zones = **2 cores**
```hcl
node_count              = 1          # was 3
vm_size                 = "Standard_B2s"  # was "Standard_D4s_v3"
enable_auto_scaling     = false      # was true
# REMOVE: min_count, max_count, zones
```
**Savings:** ~$405/mo

#### 1.3 AKS Publisher Node Pool (lines 863-882)
**Current:** 3× Standard_D2s_v3, autoscale 3-10, zones 1-2-3 = **6 cores**
**Target:** 1× Standard_B2s, no autoscale, no zones = **2 cores**
```hcl
node_count              = 1          # was 3
vm_size                 = "Standard_B2s"  # was "Standard_D2s_v3"
enable_auto_scaling     = false      # was true
# REMOVE: min_count, max_count, zones
```
**Savings:** ~$195/mo

> **AKS total: 30 cores → 6 cores, saving ~$1,020/mo**

#### 1.4 PostgreSQL (lines 271-300, module call `module.shared_postgresql`)
**Current (already changed via CLI):** Now B_Standard_B1ms, 64GB storage, 7-day backup
**Terraform changes needed to match:**
```hcl
# Line 287:
sku_name                      = "B_Standard_B1ms"  # was "GP_Standard_D4s_v3"
# Line 288: storage cannot be decreased (Azure limitation), keep at 65536
storage_mb                    = 65536
# Line 289:
backup_retention_days         = 7   # was 35
# Line 290:
geo_redundant_backup_enabled  = false  # was true (NOTE: cannot disable via CLI, do via Terraform)
```
**Savings:** ~$280/mo (D4s_v3 $300 → B1ms ~$20/mo)

#### 1.5 Redis (lines 335-351, module call `module.shared_redis`)
**Current (already changed via CLI):** Now Standard C1
**Terraform change:**
```hcl
# Line 343:
capacity = 1  # was 2
```
**Savings:** ~$50/mo (C2 ~$100 → C1 ~$50)

#### 1.6 Service Bus (lines 354-386, module call `module.shared_servicebus`)
**Current:** Premium, capacity 1, zone_redundant true
**Target:** Standard (matches dev/staging)
```hcl
# Line 360:
sku           = "Standard"  # was "Premium"
# REMOVE line 361: capacity = 1  (not applicable for Standard)
# REMOVE line 362: zone_redundant = true  (not applicable for Standard)
```
**Savings:** ~$665/mo (Premium 1MU ~$675 → Standard ~$10)

> **WARNING:** Premium → Standard is a **destructive, non-reversible in-place change**. Azure does not support downgrading a Service Bus namespace tier. This requires creating a new Standard namespace and migrating all resources.

**Service Bus Migration Playbook:**

**Pre-migration (before any Terraform changes):**

1. Export all topics, subscriptions, filters, and shared access policies:

   ```bash
   az servicebus topic list --namespace-name <premium-namespace> -g mys-prod-core-rg-san -o json > sb-topics-backup.json
   az servicebus topic subscription list --namespace-name <premium-namespace> -g mys-prod-core-rg-san --topic-name <each-topic> -o json > sb-subs-backup.json
   az servicebus namespace authorization-rule list --namespace-name <premium-namespace> -g mys-prod-core-rg-san -o json > sb-auth-rules-backup.json
   ```

2. Identify all applications using the namespace connection strings (check app settings, Key Vault references, and environment variables in AKS deployments)
3. Plan for a maintenance window — messages in-flight during the switch will be lost unless the queue is drained first

**Terraform approach:**

- Create the new Standard namespace with a different name (e.g. add `-v2` suffix) so both can coexist during migration
- Add `lifecycle { create_before_destroy = true }` if using the same name is required
- Update the module call:

  ```hcl
  sku            = "Standard"  # was "Premium"
  # REMOVE: capacity = 1
  # REMOVE: zone_redundant = true
  ```

**Migration steps:**

1. `terraform apply` — creates the new Standard namespace (old Premium still exists if using `-v2` name)
2. Recreate topics, subscriptions, and filters in the new namespace (via Terraform or `az servicebus` CLI)
3. Update application connection strings to point to the new namespace and redeploy
4. Verify all topics/subscriptions are receiving and processing messages correctly
5. Drain remaining messages from the old Premium namespace
6. `terraform apply` to destroy the old Premium namespace (or `az servicebus namespace delete`)

**Rollback plan:**

- Retain the old Premium namespace for 24-48 hours after migration
- If issues arise, switch application connection strings back to the Premium namespace
- Re-export any topic/subscription configs created in the new namespace using `az servicebus` CLI
- Document the Premium namespace name and connection string in a secure location before deletion

#### 1.7 Static Web App — Story Generator (line 496, module call `module.story_generator`)
**Current (already changed via CLI):** Now Free
**Terraform change:**
```hcl
static_web_app_sku = "Free"  # was "Standard"
```
**Savings:** ~$9/mo

#### 1.8 AI Model Deployments (lines 437-459, module call `module.shared_azure_ai`)
**Current:** gpt-4o-mini capacity=100, text-embedding-3-large capacity=240, text-embedding-3-small capacity=240
**Target:** Reduce to match staging or lower
```hcl
# Lines 437-443 (gpt-4o-mini):
capacity = 20  # was 100

# Lines 446-452 (text-embedding-3-large):
capacity = 60  # was 240

# Lines 453-459 (text-embedding-3-small):
capacity = 60  # was 240
```
**Savings:** Capacity is pay-per-use for GlobalStandard, but reducing provisioned TPM lowers reserved throughput costs.

#### 1.9 App Service Plan (already done via CLI)
**Current:** B1 (was P1v3)
**No further Terraform change needed if the ASP is defined in a module.** Find the module that creates `mys-prod-mystira-plan-san` and change the sku to `B1`.
**Savings:** ~$115/mo (P1v3 ~$130 → B1 ~$15)

#### 1.10 Publisher Redis — `mys-prod-publisher-cache-san`
**Resource Group:** mys-prod-publisher-rg-san
**Current:** Standard C1
**Action:** Evaluate if this is a duplicate of `mys-prod-core-cache`. If so, consolidate and delete the publisher cache.
**Potential savings:** ~$50/mo

---

### 2. STAGING — `infra/terraform/environments/staging/main.tf`

#### 2.1 AKS Default Node Pool (lines 779-784)
**Current:** 3× Standard_D2s_v3 = **6 cores**
**Target:** 1× Standard_B2s = **2 cores**
```hcl
node_count = 1           # was 3
vm_size    = "Standard_B2s"  # was "Standard_D2s_v3"
```
**Savings:** ~$180/mo

#### 2.2 AKS Chain Node Pool (lines 217-231, module call `module.chain`)
**Current:** chain_node_count = 2
**Target:** 1
```hcl
# Line 224:
chain_node_count = 1  # was 2
```

#### 2.3 AI Search (lines 440-459, module call `module.shared_azure_search`)
**Current:** standard tier
**Target:** basic (match dev)
```hcl
# Line 451:
sku = "basic"  # was "standard"
# REMOVE semantic_search_sku line if present (not supported on basic)
```
**Savings:** ~$240/mo (Standard ~$250 → Basic ~$10)

#### 2.4 AI Model Deployments (lines 408-430)
**Current:** gpt-4o-mini capacity=40, text-embedding-3-large capacity=120, text-embedding-3-small capacity=120
**Target:** Halve capacity
```hcl
# gpt-4o-mini (lines 408-414):
capacity = 20  # was 40

# text-embedding-3-large (lines 417-423):
capacity = 60  # was 120

# text-embedding-3-small (lines 424-430):
capacity = 60  # was 120
```

---

### 3. DEV — `infra/terraform/environments/dev/main.tf`

#### 3.1 AKS Default Node Pool (lines 857-862)
**Current:** 2× Standard_B2s = **4 cores**
**Target:** 1× Standard_B2s = **2 cores**
```hcl
# Line 859:
node_count = 1  # was 2
```
**Savings:** ~$15/mo

#### 3.2 AKS Chain Node Pool (line 296)
**Current:** chain_node_count = 1
**Target:** Already at minimum. No change needed.

---

### 4. West US Resources — `prod-wus-rg-mystira`

This entire resource group appears to be a secondary deployment in West US with:
- App Service Plan `prod-wus-app-mystira-api-plan` (P0v3, ~$70/mo)
- 2 Web Apps: `prod-wus-app-mystira-api`, `prod-wus-app-mystira-api-admin`
- Cosmos DB: `prodwusappmystiracosmos`
- Storage: `prodwusappmystirastorage` (Standard_GRS)
- Communication Services: `prod-wus-acs-mystira`, `prod-wus-ecs-mystira`

**Recommendation:** If this is unused or only serves a few users, consider **deleting the entire resource group** and consolidating into SouthAfricaNorth. The P0v3 plan couldn't be downgraded (zero VM quota in West US for any lower tier).

If it must stay:
- File a quota request for Basic VMs in West US to allow B1 scaling
- Or recreate as a Container App (consumption plan) for near-zero cost

**Potential savings:** ~$100+/mo (P0v3 + Cosmos + storage)

---

### 5. Front Door Profiles

| Name | Resource Group | SKU |
|------|---------------|-----|
| mystira-prod-fd | mys-prod-core-rg-san | Standard_AzureFrontDoor |
| mystira-nonprod-fd | mys-dev-core-rg-san | Standard_AzureFrontDoor |

**Current:** Two Standard Azure Front Door profiles (~$35/mo each)
**Recommendation:**
- Merge into a single Front Door profile with multiple endpoints (prod + dev/staging)
- Or delete the nonprod one if dev/staging don't need CDN/WAF
**Potential savings:** ~$35/mo

---

### 6. Storage Account — Premium_ZRS

| Name | Resource Group | SKU |
|------|---------------|-----|
| mysprodchainstgsan | mys-prod-chain-rg-san | Premium_ZRS (FileStorage) |

**Current:** Premium_ZRS FileStorage
**Note:** Premium FileStorage cannot be downgraded in-place. To change:
1. Create a new Standard_LRS FileStorage account
2. Migrate file shares using `azcopy`
3. Update Terraform to reference new account
4. Delete old account

**Potential savings:** ~$15/mo (minor, only worth doing as part of a larger cleanup)

---

### 7. Cosmos DB Accounts (6 total)

| Name | Resource Group | Throughput |
|------|---------------|------------|
| mys-prod-core-cosmos-san | mys-prod-core-rg-san | 7 containers × 400 RU/s = 2,800 RU/s |
| mys-prod-mystira-cosmos-san | mys-prod-mystira-rg-san | TBD |
| prodwusappmystiracosmos | prod-wus-rg-mystira | TBD |
| mys-dev-core-cosmos-san | mys-dev-core-rg-san | Serverless |
| mys-staging-core-cosmos-san | mys-staging-core-rg-san | Serverless |
| mys-dev-story-cosmos-san | mys-dev-story-rg-san | Serverless |

**Prod core** is using provisioned throughput at minimum (400 RU/s per container). Consider switching to **Serverless** mode (like dev/staging) if traffic is bursty and low. Serverless caps at 1,000 RU/s but charges per-request.

> **Note:** Switching from Provisioned to Serverless requires recreating the account (export data → create serverless account → import data). Only do this if usage is consistently low.

**Potential savings:** ~$20-40/mo (2,800 provisioned RU/s → serverless for low-traffic app)

---

## Cost Summary

| Category | Current Est. | Target Est. | Monthly Savings |
|----------|-------------|-------------|-----------------|
| **Prod AKS (3 pools)** | ~$1,050 | ~$45 | **~$1,005** |
| **Prod PostgreSQL** | ~$300 | ~$20 | **~$280** |
| **Prod Service Bus** | ~$675 | ~$10 | **~$665** |
| **Staging AI Search** | ~$250 | ~$10 | **~$240** |
| **Prod App Service Plan** | ~$130 | ~$15 | **~$115** |
| **Prod Redis** | ~$100 | ~$50 | **~$50** |
| **West US resources** | ~$100+ | $0-10 | **~$90+** |
| **Front Door consolidation** | ~$70 | ~$35 | **~$35** |
| **Static Web Apps (2)** | ~$18 | $0 | **~$18** |
| **Dev AKS** | ~$30 | ~$15 | **~$15** |
| **Staging AKS** | ~$200 | ~$15 | **~$185** |
| **Cosmos DB** | ~$60 | ~$20 | **~$40** |
| **Storage Premium** | ~$20 | ~$5 | **~$15** |
| | | **TOTAL** | **~$2,750/mo** |

---

## Core Quota After All Changes

| Resource | Cores |
|----------|-------|
| Prod AKS (3 pools × 1 node × B2s) | 6 |
| Staging AKS (2 pools × 1 node × B2s) | 4 |
| Dev AKS (1 default + 1 chain × B2s) | 4 |
| Actions runner listener (B1ms) | 1 |
| Actions runner VMSS (1-4 × B1s) | 1-4 |
| **Total** | **16-19** |

### BLOCKING PRECONDITION: Quota Increase Required

> The current SouthAfricaNorth regional vCPU quota is **10 cores**. The target state requires **16-19 cores**. **You must request and receive a quota increase before running `terraform apply` on any environment that starts AKS clusters.** Without this, Terraform will fail with `OperationNotAllowed` errors.

**Quota request procedure:**

1. Go to Azure Portal → Subscriptions → Usage + quotas
2. Request increase for "Total Regional vCPUs" in SouthAfricaNorth to **at least 20** (recommended: 25 for headroom)
3. Wait for approval (typically 1-4 hours for small increases)
4. Verify: `az vm list-usage --location southafricanorth --query "[?name.value=='cores'].{current:currentValue, limit:limit}" -o table`

**Temporary mitigation (if quota approval is delayed):**

If the quota increase is not approved in time, change AKS node VM size from `Standard_B2s` (2 cores) to `Standard_B1s` (1 core) across all environments:

| Resource | B2s cores | B1s cores |
| -------- | --------- | --------- |
| Prod AKS (3 pools) | 6 | 3 |
| Staging AKS (2 pools) | 4 | 2 |
| Dev AKS (2 pools) | 4 | 2 |
| Runner listener + VMSS | 2-5 | 2-5 |
| **Total** | **16-19** | **9-12** |

With B1s nodes, the total fits within 10 cores (at VMSS=1). However, **B1s has only 1 vCPU and 0.5 GiB RAM** — this may be too constrained for Kubernetes system pods (kubelet, kube-proxy, CoreDNS). Monitor pod scheduling failures and switch to B2s once quota is approved. Mark this as a **temporary mitigation only**.

---

## Implementation Order

1. **PREREQUISITE: Submit quota increase request** — Request SouthAfricaNorth "Total Regional vCPUs" increase to at least 20 cores (see "Quota Increase Required" above). Do not proceed with AKS-related applies until approved.
2. **PREREQUISITE: Reconcile Terraform drift** — Update all Terraform code for CLI-changed resources (see "Terraform Drift Reconciliation" above). Run `terraform plan` in each environment and verify no unexpected drift-reverting changes.
3. **Terraform code changes (all envs):** Update all values in `main.tf` files as specified in sections 1-3 above
4. **`terraform fmt -check`** in each environment
5. **Wait for quota approval** — Verify with `az vm list-usage`. If delayed, apply the B1s temporary mitigation.
6. **Dev first:** `az aks start` the cluster, then `terraform plan` + `terraform apply` (lowest risk)
7. **Staging:** `az aks start` the cluster, then `terraform plan` + `terraform apply`
8. **Prod (non-Service Bus):** `terraform plan` + `terraform apply` for AKS, PostgreSQL, Redis, SWA, AI model changes only. **Exclude Service Bus changes from this apply.**
9. **Prod Service Bus migration:** Follow the Service Bus Migration Playbook (section 1.6) as a separate operation
10. **Start AKS clusters:** `az aks start` for any remaining stopped clusters
11. **West US:** Decide keep or delete, handle separately
12. **Front Door:** Consolidate if desired (optional, low priority)
13. **Cosmos DB:** Evaluate serverless migration (optional, low priority)

---

## Notes

- All AKS clusters are currently **stopped** (dev + staging via `az aks stop`). Prod AKS was not stopped because it has users. When you `terraform apply` the AKS changes, the clusters will need to be started first.
- The PostgreSQL and Redis changes are already live (done via CLI). Terraform will see drift and align the code.
- Static Web Apps are already downgraded to Free. The prod mystira SWA has a custom domain (`mystira.app`) — Free tier supports 2 custom domains, so this should still work.
- The `mys-prod-publisher-cache-san` Redis is a separate cache in `mys-prod-publisher-rg-san`. Investigate whether the publisher service can share the core cache.
