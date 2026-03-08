# Setup self-hosted GitHub Actions runner on Windows for JustAGhosT/agentkit-forge
# Run this script in an elevated PowerShell session.
#
# Usage:
#   $env:GITHUB_RUNNER_TOKEN = "<token-from-github-ui>"
#   .\setup-windows-runner.ps1
#
# To obtain the token:
#   1. Go to https://github.com/JustAGhosT/agentkit-forge/settings/actions/runners/new
#   2. Select "Windows" / "x64"
#   3. Copy the token shown in the configure step

param(
    [string]$RunnerVersion = "2.332.0",
    [string]$RunnerName    = "agentkit-forge-win",
    [string]$RunnerDir     = "\actions-runner",
    [string]$RepoUrl       = "https://github.com/JustAGhosT/agentkit-forge",
    [string]$Labels        = "self-hosted,windows,x64",
    # SHA256 hash for the runner zip. Default matches v2.332.0.
    # When overriding RunnerVersion, set this to the matching hash from
    # https://github.com/actions/runner/releases or use "" to skip verification.
    [string]$ExpectedHash  = "83E56E05B21EB58C9697F82E52C53B30867335FF039CD5D44D1A1A24D2149F4B"
)

$ErrorActionPreference = "Stop"

$Token = $env:GITHUB_RUNNER_TOKEN
if (-not $Token) {
    Write-Error "Set GITHUB_RUNNER_TOKEN env var first. Get it from GitHub Settings > Actions > Runners > New self-hosted runner."
    exit 1
}

$ZipName    = "actions-runner-win-x64-${RunnerVersion}.zip"
$DownloadUrl = "https://github.com/actions/runner/releases/download/v${RunnerVersion}/${ZipName}"

# Create runner directory under drive root (recommended by GitHub)
Write-Host "Creating runner directory: $RunnerDir"
if (-not (Test-Path $RunnerDir)) {
    New-Item -ItemType Directory -Path $RunnerDir | Out-Null
}
Set-Location $RunnerDir

# Download runner package
Write-Host "Downloading actions-runner v${RunnerVersion}..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipName

# Validate checksum
if ($ExpectedHash) {
    Write-Host "Validating SHA256 hash..."
    $ActualHash = (Get-FileHash -Path $ZipName -Algorithm SHA256).Hash.ToUpper()
    if ($ActualHash -ne $ExpectedHash.ToUpper()) {
        Remove-Item $ZipName -Force
        Write-Error "Checksum mismatch! Expected: $ExpectedHash  Got: $ActualHash"
        exit 1
    }
    Write-Host "Checksum OK."
} else {
    Write-Warning "Hash verification skipped (ExpectedHash not provided)."
}

# Extract
Write-Host "Extracting runner..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$ZipName", "$PWD")
Remove-Item $ZipName -Force

# Configure
Write-Host "Configuring runner for $RepoUrl ..."
& .\config.cmd --url $RepoUrl --token $Token --name $RunnerName --labels $Labels --unattended --replace

# Install and start as a Windows service
Write-Host "Installing runner as a Windows service..."
& .\svc.cmd install
& .\svc.cmd start

Write-Host ""
Write-Host "Runner '$RunnerName' installed and running as a service."
Write-Host "Check status:  .\svc.cmd status"
Write-Host ""
Write-Host "Use this in your workflow files:"
Write-Host "  runs-on: self-hosted"
