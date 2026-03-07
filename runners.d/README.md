# runners.d — Persistent Runner Configurations

Each `.conf` file defines one GitHub Actions runner registration.

**Note:** `.conf` files are sourced as bash scripts — only commit trusted content.

## Adding a new runner

Create a new `.conf` file (name it after the repo):

```bash
cp agentkit-forge.conf my-new-repo.conf
```

Edit the values:

```bash
# Required
GITHUB_REPO_URL=https://github.com/owner/repo
RUNNER_NAME=my-repo-runner

# Optional (defaults shown)
RUNNER_LABELS=self-hosted,Linux,X64,azure-vnet-ghost
RUNNER_DIR=/opt/gh-runner-${RUNNER_NAME}
```

Then run:

```bash
export GITHUB_RUNNER_TOKEN="<token>"
./scripts/install-persistent-runner.sh runners.d/my-new-repo.conf
```

Or install all runners at once:

```bash
./scripts/install-all-runners.sh
```
