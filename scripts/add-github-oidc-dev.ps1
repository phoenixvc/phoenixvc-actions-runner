param(
  [string]$AppClientId = $env:ARM_CLIENT_ID,
  [string]$AppDisplayName,
  [string]$CredentialName = "github-oidc-dev",
  [string]$Subject = "repo:phoenixvc/phoenixvc-actions-runner:ref:refs/heads/dev",
  [string]$Issuer = "https://token.actions.githubusercontent.com",
  [string]$Audience = "api://AzureADTokenExchange",
  [string]$Description = "GitHub OIDC for dev branch"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
az account show -o none | Out-Null
if ([string]::IsNullOrWhiteSpace($AppClientId) -and [string]::IsNullOrWhiteSpace($AppDisplayName) -and $env:AZURE_CREDENTIALS) {
  try { $AppClientId = (ConvertFrom-Json -InputObject $env:AZURE_CREDENTIALS).clientId } catch {}
}
if ([string]::IsNullOrWhiteSpace($AppClientId) -and -not [string]::IsNullOrWhiteSpace($AppDisplayName)) {
  $AppClientId = az ad app list --filter "displayName eq '$AppDisplayName'" --query "[0].appId" -o tsv
}
if ([string]::IsNullOrWhiteSpace($AppClientId)) { throw "AppClientId not provided and could not be resolved" }
$objectId = az ad app show --id $AppClientId --query id -o tsv
if ([string]::IsNullOrWhiteSpace($objectId)) { throw "Unable to resolve App Object ID from AppClientId" }
$payload = @{
  name        = $CredentialName
  issuer      = $Issuer
  subject     = $Subject
  description = $Description
  audiences   = @($Audience)
} | ConvertTo-Json -Depth 3
$tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "fid-$($CredentialName).json")
[System.IO.File]::WriteAllText($tmp, $payload, [System.Text.Encoding]::UTF8)
az ad app federated-credential create --id $objectId --parameters $tmp
az ad app federated-credential list --id $objectId -o table
