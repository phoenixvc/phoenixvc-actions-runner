param(
  [string]$Owner = "phoenixvc",
  [string]$Repo = "phoenixvc-actions-runner",
  [string[]]$Branches = @("dev","main"),
  [int]$RequiredApprovals = 1,
  [switch]$EnforceAdmins
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh CLI not authenticated. Run 'gh auth login' first." }
$payload = [pscustomobject]@{
  required_status_checks = $null
  enforce_admins = [bool]$EnforceAdmins
  required_pull_request_reviews = [pscustomobject]@{ required_approving_review_count = $RequiredApprovals }
  restrictions = $null
  allow_deletions = $false
  allow_force_pushes = $false
} | ConvertTo-Json -Depth 3
$tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),"branch-protection.json")
[System.IO.File]::WriteAllText($tmp,$payload,[System.Text.Encoding]::UTF8)
foreach ($b in $Branches) {
  & gh api -X PUT "repos/$Owner/$Repo/branches/$b/protection" --input $tmp
}
Write-Host "Branch protection applied to: $($Branches -join ', ')"
