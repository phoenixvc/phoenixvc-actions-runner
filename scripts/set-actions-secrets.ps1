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
  [string]$RunnerLocation,
  [string]$RunnerTags,
  [string]$RunnerAlertEmail
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh CLI not authenticated. Run 'gh auth login' first." }

function Set-GitHubSecret([string]$Name, [string]$Value, [bool]$Optional = $false) {
  if (-not $Value) {
    if (-not $Optional) { throw "Required secret $Name is missing" }
    return
  }
  & gh secret set $Name -R "$Owner/$Repo" --body "$Value"
  if ($LASTEXITCODE -ne 0) { throw "gh secret set $Name failed ($LASTEXITCODE)" }
}

function Set-GitHubVariable([string]$Name, [string]$Value, [bool]$Optional = $false) {
  if (-not $Value) {
    if (-not $Optional) { throw "Required variable $Name is missing" }
    return
  }
  & gh variable set $Name -R "$Owner/$Repo" --value "$Value"
  if ($LASTEXITCODE -ne 0) { throw "gh variable set $Name failed ($LASTEXITCODE)" }
}

Set-GitHubSecret "ARM_CLIENT_ID" $ARMClientId
Set-GitHubSecret "ARM_TENANT_ID" $ARMTenantId
Set-GitHubSecret "ARM_SUBSCRIPTION_ID" $ARMSubscriptionId
Set-GitHubSecret "RUNNER_SUBNET_ID" $RunnerSubnetId
Set-GitHubSecret "RUNNER_SSH_PUBLIC_KEY" $RunnerSSHPublicKey
Set-GitHubSecret "AZURE_CREDENTIALS" $AzureCredentialsJson -Optional $true
Set-GitHubVariable "RUNNER_RESOURCE_GROUP_NAME" $RunnerResourceGroupName
Set-GitHubVariable "RUNNER_LOCATION" $RunnerLocation
Set-GitHubVariable "RUNNER_TAGS" $RunnerTags -Optional $true
Set-GitHubVariable "RUNNER_ALERT_EMAIL" $RunnerAlertEmail -Optional $true
Write-Host "Secrets and variables updated on $Owner/$Repo"
