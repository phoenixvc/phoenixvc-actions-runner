# Runner Infrastructure Recommendations

This document prioritizes actionable improvements for the `phoenixvc-actions-runner` setup. Each recommendation is detailed in its own dedicated guide.

## Priority Matrix

| Priority | Recommendation | Impact | Key Benefit |
|----------|----------------|--------|-------------|
| **1. High** | [Custom Machine Images](recommendations/01-custom-images.md) | Very High | Slashes cold start time from mins to secs. |
| **2. High** | [Dynamic Scale-to-Zero](recommendations/02-scale-to-zero.md) | High | Eliminates idle costs during off-hours. |
| **3. Medium**| [Security Hardening](recommendations/03-security-hardening.md) | High | Automated patching & network auditing. |
| **4. Low**   | [Monitoring & Alerting](recommendations/04-monitoring.md) | Medium | Better visibility into job queue latency. |
| **5. Low**   | [GitHub-Hosted Eval](recommendations/05-github-hosted-eval.md) | Low | Potential for lower maintenance overhead. |

---

## High Impact Recommendations

### [Custom Machine Images (Gold Image)](recommendations/01-custom-images.md)
**The most critical performance improvement.** By baking our tools (Docker, Node, Terraform) directly into a private Azure image, we eliminate the 3-5 minute installation delay that currently occurs on every runner boot.

### [Dynamic Scale-to-Zero](recommendations/02-scale-to-zero.md)
**The most critical cost improvement.** This ensures that when no work is happening, we aren't paying for warm instances. Combined with Custom Images, the "wait time" for the first job will be negligible.

---

## Secondary Improvements

- **[Security Hardening](recommendations/03-security-hardening.md)**: Moving from manual maintenance to automated Azure Update Management.
- **[Enhanced Monitoring](recommendations/04-monitoring.md)**: Building a dashboard to prove why we need (or don't need) more runner capacity.
- **[GitHub-Hosted Evaluation](recommendations/05-github-hosted-eval.md)**: A strategic look at the trade-offs between self-hosting and managed services.
