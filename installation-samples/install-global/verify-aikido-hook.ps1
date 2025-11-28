#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

# Check if core.hooksPath is set
$hooksPath = git config --global core.hooksPath 2>$null

if (-not $hooksPath) {
    Write-Host "❌ core.hooksPath is not set" -ForegroundColor Red
    exit 1
}

Write-Host "✅ core.hooksPath is set to: $hooksPath" -ForegroundColor Green

# Check if pre-commit hook exists
$hookScript = Join-Path $hooksPath "pre-commit"
if (-not (Test-Path $hookScript)) {
    Write-Host "❌ Pre-commit hook file not found at: $hookScript" -ForegroundColor Red
    exit 1
}

# Check if aikido-local-scanner is mentioned in the hook
$hookContent = Get-Content $hookScript -Raw
if ($hookContent -notmatch "aikido-local-scanner") {
    Write-Host "❌ aikido-local-scanner not found in pre-commit hook" -ForegroundColor Red
    exit 1
}

Write-Host "✅ aikido-local-scanner found in pre-commit hook" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Verification complete: Aikido pre-commit hook is installed" -ForegroundColor Green

