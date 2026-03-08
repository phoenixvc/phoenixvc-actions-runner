#!/bin/bash
# Install a persistent GitHub Actions runner on Linux.
#
# Usage:
#   # Single runner via conf file:
#   export GITHUB_RUNNER_TOKEN="<token>"
#   ./install-persistent-runner.sh ../runners.d/agentkit-forge.conf
#
#   # Single runner via env vars:
#   export GITHUB_RUNNER_TOKEN="<token>"
#   export GITHUB_REPO_URL="https://github.com/JustAGhosT/agentkit-forge"
#   export RUNNER_NAME="agentkit-forge-linux"
#   ./install-persistent-runner.sh
#
# To obtain the token:
#   Go to https://github.com/<owner>/<repo>/settings/actions/runners/new
#   Select "Linux" / "x64" and copy the token from the configure step.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source runner version
if [ -f "${SCRIPT_DIR}/../runner-version.env" ]; then
  # shellcheck source=../runner-version.env
  source "${SCRIPT_DIR}/../runner-version.env"
fi
VERSION="${RUNNER_VERSION:-2.332.0}"

# Source conf file if provided as argument
if [ -n "$1" ] && [ -f "$1" ]; then
  echo "Loading config: $1"
  # Validate conf file contains only expected variable assignments (no trailing commands)
  if grep -qvE '^\s*(#|$|GITHUB_REPO_URL=[^;]*$|RUNNER_NAME=[^;]*$|RUNNER_LABELS=[^;]*$|RUNNER_DIR=[^;]*$)' "$1"; then
    echo "ERROR: conf file contains unexpected or unsafe content:" >&2
    grep -nE -v '^\s*(#|$|GITHUB_REPO_URL=[^;]*$|RUNNER_NAME=[^;]*$|RUNNER_LABELS=[^;]*$|RUNNER_DIR=[^;]*$)' "$1" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "$1"
elif [ -n "$1" ]; then
  echo "Config file not found: $1" >&2
  exit 1
fi

# Validate required vars
GITHUB_REPO_URL="${GITHUB_REPO_URL:?Set GITHUB_REPO_URL (e.g. https://github.com/owner/repo)}"
TOKEN="${GITHUB_RUNNER_TOKEN:?Set GITHUB_RUNNER_TOKEN — get from repo Settings > Actions > Runners > New self-hosted runner}"
RUNNER_NAME="${RUNNER_NAME:-azure-vnet-ghost}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,Linux,X64,azure-vnet-ghost}"
RUNNER_DIR="${RUNNER_DIR:-/opt/gh-runner-${RUNNER_NAME}}"

# Install Azure CLI if missing
if ! command -v az &>/dev/null; then
  echo "Azure CLI not found — installing..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

echo "=== Installing runner: ${RUNNER_NAME} ==="
echo "  Repo:   ${GITHUB_REPO_URL}"
echo "  Labels: ${RUNNER_LABELS}"
echo "  Dir:    ${RUNNER_DIR}"

# Stop existing service if re-installing
if [ -f "${RUNNER_DIR}/svc.sh" ]; then
  echo "Stopping existing runner service..."
  sudo "${RUNNER_DIR}/svc.sh" stop 2>/dev/null || true
  sudo "${RUNNER_DIR}/svc.sh" uninstall 2>/dev/null || true
fi

sudo mkdir -p "$RUNNER_DIR"
sudo chown "$USER" "$RUNNER_DIR"
cd "$RUNNER_DIR"

curl -sL "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz" | tar xz

./config.sh \
  --url "$GITHUB_REPO_URL" \
  --token "$TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --replace \
  --unattended

sudo ./svc.sh install
sudo ./svc.sh start

echo "Runner '${RUNNER_NAME}' installed and running."
echo "  Status: sudo ${RUNNER_DIR}/svc.sh status"
