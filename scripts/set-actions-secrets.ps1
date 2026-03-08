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
if ($ARMClientId -and $LASTEXITCODE -ne 0) { Write-Error "gh secret set ARM_CLIENT_ID failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($ARMTenantId) { & gh secret set ARM_TENANT_ID -R "$Owner/$Repo" --body "$ARMTenantId" }
if ($ARMTenantId -and $LASTEXITCODE -ne 0) { Write-Error "gh secret set ARM_TENANT_ID failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($ARMSubscriptionId) { & gh secret set ARM_SUBSCRIPTION_ID -R "$Owner/$Repo" --body "$ARMSubscriptionId" }
if ($ARMSubscriptionId -and $LASTEXITCODE -ne 0) { Write-Error "gh secret set ARM_SUBSCRIPTION_ID failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($RunnerSubnetId) { & gh secret set RUNNER_SUBNET_ID -R "$Owner/$Repo" --body "$RunnerSubnetId" }
if ($RunnerSubnetId -and $LASTEXITCODE -ne 0) { Write-Error "gh secret set RUNNER_SUBNET_ID failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($RunnerSSHPublicKey) { & gh secret set RUNNER_SSH_PUBLIC_KEY -R "$Owner/$Repo" --body "$RunnerSSHPublicKey" }
if ($RunnerSSHPublicKey -and $LASTEXITCODE -ne 0) { Write-Error "gh secret set RUNNER_SSH_PUBLIC_KEY failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($AzureCredentialsJson) { & gh secret set AZURE_CREDENTIALS -R "$Owner/$Repo" --body "$AzureCredentialsJson" }
if ($AzureCredentialsJson -and $LASTEXITCODE -ne 0) { Write-Error "gh secret set AZURE_CREDENTIALS failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($RunnerResourceGroupName) { & gh variable set RUNNER_RESOURCE_GROUP_NAME -R "$Owner/$Repo" --value "$RunnerResourceGroupName" }
if ($RunnerResourceGroupName -and $LASTEXITCODE -ne 0) { Write-Error "gh variable set RUNNER_RESOURCE_GROUP_NAME failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
if ($RunnerLocation) { & gh variable set RUNNER_LOCATION -R "$Owner/$Repo" --value "$RunnerLocation" }
if ($RunnerLocation -and $LASTEXITCODE -ne 0) { Write-Error "gh variable set RUNNER_LOCATION failed ($LASTEXITCODE)"; exit $LASTEXITCODE }
Write-Host "Secrets and variables updated on $Owner/$Repo"
