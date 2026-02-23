#!/bin/bash
# VMSS instance startup script - fetches JIT config and runs ephemeral runner
# The Scale Set Client must expose an HTTP endpoint or write JIT configs to a shared location.
# This is a placeholder - integrate with your Scale Set Client's provisioning logic.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../runner-version.env
source "${SCRIPT_DIR}/../runner-version.env"
VERSION="${RUNNER_VERSION}"

JIT_ENDPOINT="${JIT_ENDPOINT:-http://10.0.4.4:8080/jit}"
RUNNER_DIR="/opt/gh-runner"

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

curl -sL "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz" | tar xz

JIT_RESPONSE=$(curl -sf "$JIT_ENDPOINT" || echo "")
if [ -z "$JIT_RESPONSE" ]; then
  echo "Failed to get JIT config. Ensure listener exposes $JIT_ENDPOINT"
  exit 1
fi

./config.sh --url https://github.com/phoenixvc --ephemeral --unattended $JIT_RESPONSE
./run.sh
