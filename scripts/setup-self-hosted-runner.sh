#!/bin/bash
# Guided setup for phoenixvc + JustAGhosT self-hosted runners
set -e

GITHUB_APP_DESCRIPTION="Manages ephemeral GitHub Actions runners for phoenixvc org. Scales VMSS based on workflow demand. Used by Scale Set Client for Key Vault and Storage access from Azure VNet."

echo "=== Phase 1: Create GitHub App ==="
echo ""
echo "1. Go to phoenixvc org -> Settings -> Developer settings -> GitHub Apps -> New GitHub App"
echo "2. Name: phoenixvc-actions-runner"
echo "3. Description (copy-paste):"
echo "   $GITHUB_APP_DESCRIPTION"
echo ""
echo "4. Homepage URL: https://github.com/phoenixvc"
echo "5. Permissions -> Organization permissions:"
echo "   - Administration: Read and write"
echo "   - Self-hosted runners: Read and write"
echo "6. Where can this GitHub App be installed? -> Only on this account"
echo "7. Webhook: Leave URL blank and secret empty (Scale Set Client uses API polling, not webhooks)"
echo "8. Create GitHub App -> Generate private key -> Install on phoenixvc org"
echo "9. Note App ID and Installation ID"
echo ""

echo "=== Phase 2: Terraform (Runner Infrastructure) ==="
echo ""
echo "Prerequisite: HouseOfVeritas deployed with runner subnet. Get subnet ID:"
echo "  cd ../HouseOfVeritas/terraform/environments/production"
echo "  terraform output -raw runner_subnet_id"
echo ""
if [ -n "$RUNNER_SSH_PUBLIC_KEY" ] && [ -n "$RUNNER_SUBNET_ID" ] && [ -n "$RESOURCE_GROUP_NAME" ] && [ -n "$LOCATION" ]; then
  echo "Vars set. Running terraform..."
  cd "$(dirname "$0")/../terraform"
  terraform init
  terraform apply -var="runner_subnet_id=$RUNNER_SUBNET_ID" -var="ssh_public_key=$RUNNER_SSH_PUBLIC_KEY" -var="resource_group_name=$RESOURCE_GROUP_NAME" -var="location=$LOCATION" -auto-approve
  LISTENER_IP=$(terraform output -raw listener_private_ip)
  echo "Listener IP: $LISTENER_IP"
else
  echo "Set env vars and run:"
  echo "  export RUNNER_SUBNET_ID=\$(cd ../HouseOfVeritas/terraform/environments/production && terraform output -raw runner_subnet_id)"
  echo "  export RUNNER_SSH_PUBLIC_KEY=\"ssh-rsa AAAAB3...\""
  echo "  export RESOURCE_GROUP_NAME=\"nl-prod-hov-rg-san\""
  echo "  export LOCATION=\"South Africa North\""
  echo "  ./scripts/setup-self-hosted-runner.sh"
fi
echo ""

echo "=== Phase 3: Install on Listener VM ==="
echo ""
echo "SSH to listener (use Azure Bastion or VPN):"
echo "  ssh azureuser@<listener-private-ip>"
echo ""
echo "Copy scripts and run:"
echo "  scp scripts/*.sh azureuser@<listener-ip>:~/"
echo "  ssh azureuser@<listener-ip>"
echo "  export GITHUB_APP_ID=... GITHUB_INSTALLATION_ID=... GITHUB_APP_KEY_PATH=/etc/phoenixvc-runner/key.pem"
echo "  ./install-scale-set-client.sh"
echo "  sudo systemctl enable --now phoenixvc-scale-set"
echo ""
echo "For JustAGhosT persistent runners:"
echo "  export GITHUB_RUNNER_TOKEN=<token-from-github-ui>"
echo "  ./install-all-runners.sh          # all runners in runners.d/"
echo "  # or a single runner:"
echo "  ./install-persistent-runner.sh runners.d/agentkit-forge.conf"
echo ""
