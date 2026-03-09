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

> **WARNING:** Premium → Standard is a destructive change. It requires creating a new namespace (Standard tier) and migrating topics/subscriptions. You cannot in-place downgrade. Consider: export topic/subscription config, destroy Premium, create Standard. If the app barely has traffic, this is fine.

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
| Staging AKS (2 pools) | 3 |
| Dev AKS (2 pools) | 3 |
| Actions runner listener (B1ms) | 1 |
| Actions runner VMSS (0-4 × B1s) | 0-4 |
| **Total** | **13-17** |

> **Recommendation:** Request quota increase to 20 cores in SouthAfricaNorth to accommodate AKS + VMSS headroom. Current limit of 10 is too tight even after scaledown. Alternatively, use B1s (1 core) for AKS nodes instead of B2s (2 cores) to fit within 10, but B1s may be too small for Kubernetes system pods.

---

## Implementation Order

1. **Terraform changes (all envs):** Update all values in `main.tf` files as specified above
2. **`terraform fmt -check`** in each environment
3. **Dev first:** `terraform plan` + `terraform apply` in dev (lowest risk)
4. **Staging:** `terraform plan` + `terraform apply`
5. **Prod:** `terraform plan` + `terraform apply` — Service Bus change will be destructive, handle carefully
6. **West US:** Decide keep or delete, handle separately
7. **Front Door:** Consolidate if desired (optional)
8. **Cosmos DB:** Evaluate serverless migration (optional, low priority)

---

## Notes

- All AKS clusters are currently **stopped** (dev + staging via `az aks stop`). Prod AKS was not stopped because it has users. When you `terraform apply` the AKS changes, the clusters will need to be started first.
- The PostgreSQL and Redis changes are already live (done via CLI). Terraform will see drift and align the code.
- Static Web Apps are already downgraded to Free. The prod mystira SWA has a custom domain (`mystira.app`) — Free tier supports 2 custom domains, so this should still work.
- The `mys-prod-publisher-cache-san` Redis is a separate cache in `mys-prod-publisher-rg-san`. Investigate whether the publisher service can share the core cache.
