param(
  [string]$Owner = "phoenixvc",
  [string]$Repo = "phoenixvc-actions-runner",
  [string]$ARMClientId,
  [string]$ARMTenantId,
  [string]$ARMSubscriptionId,
  [string]$RunnerSubnetId,
  [string]$RunnerSSHPublicKey,
  [string]$AzureCredentialsJson,
  [string]$RunnerResourceGroupName,
  [string]$RunnerLocation
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh CLI not authenticated. Run 'gh auth login' first." }
if ($ARMClientId) { & gh secret set ARM_CLIENT_ID -R "$Owner/$Repo" --body "$ARMClientId" }
if ($ARMTenantId) { & gh secret set ARM_TENANT_ID -R "$Owner/$Repo" --body "$ARMTenantId" }
if ($ARMSubscriptionId) { & gh secret set ARM_SUBSCRIPTION_ID -R "$Owner/$Repo" --body "$ARMSubscriptionId" }
if ($RunnerSubnetId) { & gh secret set RUNNER_SUBNET_ID -R "$Owner/$Repo" --body "$RunnerSubnetId" }
if ($RunnerSSHPublicKey) { & gh secret set RUNNER_SSH_PUBLIC_KEY -R "$Owner/$Repo" --body "$RunnerSSHPublicKey" }
if ($AzureCredentialsJson) { & gh secret set AZURE_CREDENTIALS -R "$Owner/$Repo" --body "$AzureCredentialsJson" }
if ($RunnerResourceGroupName) { & gh variable set RUNNER_RESOURCE_GROUP_NAME -R "$Owner/$Repo" --value "$RunnerResourceGroupName" }
if ($RunnerLocation) { & gh variable set RUNNER_LOCATION -R "$Owner/$Repo" --value "$RunnerLocation" }
Write-Host "Secrets and variables updated on $Owner/$Repo"
