#!/bin/bash
set -euo pipefail
# Deploy GitHub App PEM key to the listener VM.
# B64KEY must be provided as an environment variable (base64-encoded PEM).
# Example: B64KEY=$(base64 -w0 < key.pem) ./write-key.sh

if [ -z "${B64KEY:-}" ]; then
  echo "Error: B64KEY environment variable not set" >&2
  exit 1
fi

sudo mkdir -p /etc/phoenixvc-runner
echo "$B64KEY" | base64 -d | sudo install -m 600 /dev/stdin /etc/phoenixvc-runner/key.pem
