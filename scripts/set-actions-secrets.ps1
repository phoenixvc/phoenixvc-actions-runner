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

function Set-Secret([string]$Name, [string]$Value) {
  if (-not $Value) { return }
  & gh secret set $Name -R "$Owner/$Repo" --body "$Value"
  if ($LASTEXITCODE -ne 0) { throw "gh secret set $Name failed ($LASTEXITCODE)" }
}

function Set-Variable([string]$Name, [string]$Value) {
  if (-not $Value) { return }
  & gh variable set $Name -R "$Owner/$Repo" --value "$Value"
  if ($LASTEXITCODE -ne 0) { throw "gh variable set $Name failed ($LASTEXITCODE)" }
}

Set-Secret "ARM_CLIENT_ID" $ARMClientId
Set-Secret "ARM_TENANT_ID" $ARMTenantId
Set-Secret "ARM_SUBSCRIPTION_ID" $ARMSubscriptionId
Set-Secret "RUNNER_SUBNET_ID" $RunnerSubnetId
Set-Secret "RUNNER_SSH_PUBLIC_KEY" $RunnerSSHPublicKey
Set-Secret "AZURE_CREDENTIALS" $AzureCredentialsJson
Set-Variable "RUNNER_RESOURCE_GROUP_NAME" $RunnerResourceGroupName
Set-Variable "RUNNER_LOCATION" $RunnerLocation
Write-Host "Secrets and variables updated on $Owner/$Repo"
