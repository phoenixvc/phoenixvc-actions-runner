param(
  [string]$Owner = "phoenixvc",
  [string]$Repo = "phoenixvc-actions-runner",
  [string[]]$Branches = @("dev", "main"),
  [int]$RequiredApprovals = 0,
  [switch]$EnforceAdmins
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
& gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "gh CLI not authenticated. Run 'gh auth login' first." }
$enforceStr = if ($EnforceAdmins) { "true" } else { "false" }
if ($RequiredApprovals -gt 0) {
  $reviewBlock = @"
  "required_pull_request_reviews": {
    "required_approving_review_count": $RequiredApprovals
  },
"@
}
else {
  $reviewBlock = "  `"required_pull_request_reviews`": null,"
}
$payload = @"
{
  "required_status_checks": null,
  "enforce_admins": $enforceStr,
$reviewBlock
  "restrictions": null,
  "allow_deletions": false,
  "allow_force_pushes": false
}
"@

$tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "branch-protection-$([System.Guid]::NewGuid()).json")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
try {
  [System.IO.File]::WriteAllText($tmp, $payload, $utf8NoBom)
  foreach ($b in $Branches) {
    Write-Host "Setting protection on $b..."
    & gh api -X PUT "repos/$Owner/$Repo/branches/$b/protection" --input $tmp
    if ($LASTEXITCODE -ne 0) { throw "Failed to set protection on $b" }
  }
  Write-Host "Branch protection applied to: $($Branches -join ', ')"
}
finally {
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
