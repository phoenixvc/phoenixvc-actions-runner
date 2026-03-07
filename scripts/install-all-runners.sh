#!/bin/bash
# Install all persistent runners defined in runners.d/*.conf
#
# Usage:
#   export GITHUB_RUNNER_TOKEN="<token>"
#   ./scripts/install-all-runners.sh
#
# Each .conf file in runners.d/ defines one runner. The same token is used
# for all runners — if repos need different tokens, install them individually:
#   GITHUB_RUNNER_TOKEN="<token-a>" ./scripts/install-persistent-runner.sh runners.d/repo-a.conf
#   GITHUB_RUNNER_TOKEN="<token-b>" ./scripts/install-persistent-runner.sh runners.d/repo-b.conf
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="${SCRIPT_DIR}/../runners.d"

if [ -z "${GITHUB_RUNNER_TOKEN}" ]; then
  echo "Set GITHUB_RUNNER_TOKEN before running this script." >&2
  exit 1
fi

confs=("${CONF_DIR}"/*.conf)
if [ ! -f "${confs[0]}" ]; then
  echo "No .conf files found in ${CONF_DIR}/" >&2
  exit 1
fi

echo "Found ${#confs[@]} runner config(s):"
for conf in "${confs[@]}"; do
  echo "  - $(basename "$conf")"
done
echo ""

failed=0
for conf in "${confs[@]}"; do
  echo "================================================================"
  if ! "${SCRIPT_DIR}/install-persistent-runner.sh" "$conf"; then
    echo "FAILED: $(basename "$conf")" >&2
    failed=$((failed + 1))
  fi
  echo ""
done

echo "================================================================"
echo "Done. ${#confs[@]} runner(s) processed, ${failed} failed."
if [ "$failed" -gt 0 ]; then
  exit 1
fi
