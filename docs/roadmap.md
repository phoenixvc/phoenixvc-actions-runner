# Runner Infrastructure Roadmap

This document outlines the strategic phases for improving the `phoenixvc-actions-runner` infrastructure.

## Phase 1: Stabilization & Visibility (Immediate)
**Goal**: Ensure current operations are documented and observable.
- [x] Audit registration scope (Org vs Repo).
- [x] Formalize documentation for OIDC and ARC comparison.
- [x] Create [Management Guide](management.md) for operations.
- [ ] Implement [Basic Monitoring](recommendations/04-monitoring.md) to establish a performance baseline.

## Phase 2: Performance & Speed (Short Term)
**Goal**: Reduce developer friction by slashing runner boot times.
- [ ] Implement [Custom Machine Images](recommendations/01-custom-images.md) (The "Gold Image" strategy).
- [ ] Measure reduction in "Action Queue Time" and boot latency.
- [ ] Refactor `cloud-init.yaml` to leverage pre-baked tools.

## Phase 3: Cost Optimization (Short Term)
**Goal**: Minimize wasted budget during idle periods.
- [ ] Implement [Dynamic Scale-to-Zero](recommendations/02-scale-to-zero.md) logic.
- [ ] Configure scheduled scale-down for non-working hours.
- [ ] Verify that combine with Phase 2 keeps cold-start impact under 45 seconds.

## Phase 4: Hardening & Evolution (Medium Term)
**Goal**: Long-term maintenance and evaluation of alternatives.
- [ ] Automate OS patching via [Azure Update Manager](recommendations/03-security-hardening.md).
- [ ] Perform annual [GitHub-Hosted Eval](recommendations/05-github-hosted-eval.md) to see if managed services now meet the org's needs.
- [ ] Evaluate migration to full Kubernetes-native ARC if the organization's AKS usage matures and simplifies.
