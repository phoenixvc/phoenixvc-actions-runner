# Recommendation 04: Enhanced Monitoring & Alerting

| Metadata | Value |
|----------|-------|
| **Priority** | Low |
| **Effort** | Medium |
| **Impact** | High (Visibility and bottleneck identification) |

## Problem Statement
While we monitor VM availability, we lack visibility into the **efficiency** of the runners. We don't know how long jobs wait in the queue before being picked up or if we are hitting scaling limits.

## Detailed Implementation Steps

### 1. Azure Monitor Workbook
Create an Azure Workbook that aggregates:
- **VMSS Instance Count**: Over time to see peak usage.
- **CPU/Memory Metrics**: For the listener VM to ensure it's not a bottleneck.

### 2. Custom Metrics for Job Latency
Since the runners are ephemeral, standard logs vanish.
1. Implement a small script in your CI workflows or the `vmss-startup.sh` that logs the time difference between `Job Queued` and `Job Started`.
2. Push this metric to **Azure Application Insights** or **GitHub Actions Workflow Metrics API**.

### 3. Log Analytics Alerts
Configure alerts in Azure Log Analytics:
- **Scaling Limit Alert**: Alert when VMSS hits `max_capacity` (10 instances) for more than 30 minutes. This indicates a need to increase the regional core quota.
- **Listener Restart Alert**: Alert if the `phoenixvc-scale-set.service` restarts more than twice in an hour.

## Expected Outcome
- Data-driven decisions on when to increase/decrease `max_capacity`.
- Faster response to infrastructure stalls.
