#!/bin/bash
# Install persistent GitHub Actions runner for JustAGhosT (personal account)
# Run on the listener VM. Serves all personal repos.
set -e

TOKEN="${GITHUB_RUNNER_TOKEN:?Set GITHUB_RUNNER_TOKEN - get from GitHub Settings > Actions > Runners > New self-hosted runner}"
RUNNER_NAME="${RUNNER_NAME:-azure-vnet-ghost}"
RUNNER_DIR="/opt/gh-runner-justaghost"
VERSION="2.311.0"

sudo mkdir -p "$RUNNER_DIR"
sudo chown "$USER" "$RUNNER_DIR"
cd "$RUNNER_DIR"

curl -sL "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz" | tar xz

./config.sh --url https://github.com/JustAGhosT --token "$TOKEN" --name "$RUNNER_NAME" --unattended

sudo ./svc.sh install
sudo ./svc.sh start

echo "Persistent runner installed. Status: sudo ./svc.sh status"
