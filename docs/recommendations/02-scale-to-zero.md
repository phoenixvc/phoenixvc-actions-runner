# Recommendation 02: Dynamic Scale-to-Zero

| Metadata | Value |
|----------|-------|
| **Priority** | High |
| **Effort** | Low |
| **Impact** | Medium (Cost reduction during idle time) |

## Problem Statement
The current infrastructure maintains a minimum capacity of `1` instance in the VMSS to ensure a hot runner is always available. During weekends or nights, this instance remains active, consuming unnecessary budget.

## Detailed Implementation Steps

### 1. Manual Schedule via GitHub Actions
Create a new workflow `.github/workflows/runner-power-schedule.yml`:
```yaml
name: Runner Power Schedule
on:
  schedule:
    - cron: '0 20 * * 1-5' # 8 PM Weekdays (Shut down)
    - cron: '0 6 * * 1-5'  # 6 AM Weekdays (Start up)
jobs:
  scale:
    runs-on: ubuntu-latest
    steps:
      - name: Scale VMSS
        run: |
          # Use az cli to update VMSS capacity
          # Logic: If 8PM, set min-capacity=0. If 6AM, set min-capacity=1.
```

### 2. Event-Driven Auto-Scaling logic
The `scaleset-client` (already installed) handles scale-up automatically when jobs are queued. The only change needed is ensuring the Terraform/Azure configuration allows the scale-set to reach `0`.

Update `terraform/variables.tf`:
```hcl
variable "vmss_min_capacity" {
  default = 0 # Change from 1 to 0
}
```

### 3. Impact on Cold Start
- **Pros**: Zero cost when no jobs are running.
- **Cons**: The first person to push code after a period of inactivity will wait for a VM to boot (~2-4 minutes).
- **Mitigation**: Combine this with **Recommendation 01 (Custom Images)** to reduce the wait for the first job to <45 seconds.

## Expected Outcome
- **Savings**: Close to 10-15% reduction in monthly infrastructure costs.
- **Convenience**: No manual "Scale Down" actions required.
