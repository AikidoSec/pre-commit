#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$INSTALL_DIR = Join-Path $env:USERPROFILE ".local\bin"
$BINARY_NAME = "aikido-local-scanner.exe"

Write-Host "Detecting git hooks directory..." -ForegroundColor Cyan

# Determine which hooks directory is being used
$currentHooksPath = git config --global core.hooksPath 2>$null
if (-not $currentHooksPath) {
    Write-Host "No global hooks path configured. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

$ACTUAL_HOOKS_DIR = $currentHooksPath
$HOOK_SCRIPT = Join-Path $ACTUAL_HOOKS_DIR "pre-commit"

Write-Host "Checking for pre-commit hook at: $HOOK_SCRIPT" -ForegroundColor Cyan

# Check if hook file exists
if (-not (Test-Path $HOOK_SCRIPT)) {
    Write-Host "Pre-commit hook file not found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Read the hook content
$hookContent = Get-Content $HOOK_SCRIPT -Raw

# Check if Aikido snippet exists in the hook
if ($hookContent -notmatch "Aikido local scanner") {
    Write-Host "Aikido scanner not found in pre-commit hook. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# Verify both markers exist before attempting removal
# This prevents accidental deletion if the end marker is missing
$hasStartMarker = ($hookContent -match '(?m)^# --- Aikido local scanner ---$')
$hasEndMarker = ($hookContent -match '(?m)^# --- End Aikido local scanner ---$')

if (-not $hasStartMarker) {
    Write-Host "Warning: Start marker not found. Aikido section may be malformed." -ForegroundColor Yellow
    Write-Host "AAborting uninstall - please manually clean up the hook file." -ForegroundColor Red
    exit 1
}

if (-not $hasEndMarker) {
    Write-Host "Error: End marker '# --- End Aikido local scanner ---' is missing!" -ForegroundColor Red
    Write-Host "Aborting uninstall - please manually clean up the hook file." -ForegroundColor Red
    exit 1
}

Write-Host "Removing Aikido snippet from pre-commit hook..." -ForegroundColor Cyan

# Remove the Aikido section strictly (between the exact markers)
# Use regex to match the entire Aikido block including markers
# We've already verified both markers exist, so this is safe
$pattern = '(?s)# --- Aikido local scanner ---.*?# --- End Aikido local scanner ---\r?\n?'
$cleanedContent = $hookContent -replace $pattern, ''

# Remove any trailing empty lines
$cleanedContent = $cleanedContent.TrimEnd()

# Write the cleaned content back
Set-Content -Path $HOOK_SCRIPT -Value $cleanedContent -NoNewline

Write-Host "Removed Aikido snippet from pre-commit hook." -ForegroundColor Green

# Clean up the binary
$BINARY_PATH = Join-Path $INSTALL_DIR $BINARY_NAME
if (Test-Path $BINARY_PATH) {
    Write-Host "Removing binary from $BINARY_PATH..." -ForegroundColor Cyan
    Remove-Item -Path $BINARY_PATH -Force
    Write-Host "Removed aikido-local-scanner binary." -ForegroundColor Green
}
else {
    Write-Host "Binary not found at $BINARY_PATH (may have been removed already)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Git hook configuration (core.hooksPath) was not modified." -ForegroundColor White
Write-Host "      If you want to remove it, run: git config --global --unset core.hooksPath" -ForegroundColor White

