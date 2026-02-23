#!/bin/bash
# Install persistent GitHub Actions runner for JustAGhosT (personal account)
# Run on the listener VM. Serves all personal repos.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../runner-version.env
if [ -f "${SCRIPT_DIR}/../runner-version.env" ]; then
  source "${SCRIPT_DIR}/../runner-version.env"
fi
VERSION="${RUNNER_VERSION:-2.311.0}"

if ! command -v az &>/dev/null; then
  echo "Azure CLI not found — installing..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

TOKEN="${GITHUB_RUNNER_TOKEN:?Set GITHUB_RUNNER_TOKEN - get from GitHub Settings > Actions > Runners > New self-hosted runner}"
RUNNER_NAME="${RUNNER_NAME:-azure-vnet-ghost}"
RUNNER_DIR="/opt/gh-runner-justaghost"
GITHUB_URL="${GITHUB_REPO_URL:-https://github.com/JustAGhosT}"

sudo mkdir -p "$RUNNER_DIR"
sudo chown "$USER" "$RUNNER_DIR"
cd "$RUNNER_DIR"

curl -sL "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz" | tar xz

./config.sh --url "$GITHUB_URL" --token "$TOKEN" --name "$RUNNER_NAME" --unattended

sudo ./svc.sh install
sudo ./svc.sh start

echo "Persistent runner installed. Status: sudo ./svc.sh status"
