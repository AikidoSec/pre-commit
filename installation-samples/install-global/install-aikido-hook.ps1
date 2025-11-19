#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$VERSION = "v1.0.111"
$BASE_URL = "https://aikido-local-scanner.s3.eu-west-1.amazonaws.com/$VERSION"
$INSTALL_DIR = Join-Path $env:USERPROFILE ".local\bin"
$GLOBAL_HOOKS_DIR = Join-Path $env:USERPROFILE ".git-hooks"

Write-Host "Detecting platform and architecture..." -ForegroundColor Cyan

# Detect architecture using environment variable
$ARCH = $env:PROCESSOR_ARCHITECTURE

Write-Host "Detected architecture: $ARCH" -ForegroundColor Gray

# Check if architecture is x64
if ($ARCH -eq "AMD64" -or $ARCH -eq "x64") {
    $PLATFORM = "windows_X86_64"
}
else {
    Write-Error "Unsupported Windows architecture: $ARCH. Only x64 is supported."
    exit 1
}

$DOWNLOAD_URL = "$BASE_URL/$PLATFORM/aikido-local-scanner.zip"
$BINARY_NAME = "aikido-local-scanner.exe"

Write-Host "Downloading aikido-local-scanner for $PLATFORM..." -ForegroundColor Cyan
Write-Host "URL: $DOWNLOAD_URL" -ForegroundColor Gray

# Create temporary directory
$TMP_DIR = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TMP_DIR | Out-Null

try {
    # Download the zip file
    $zipPath = Join-Path $TMP_DIR "aikido-local-scanner.zip"
    
    try {
        # Try BITS first (fastest and most reliable on Windows)
        if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
            Import-Module BitsTransfer
            Start-BitsTransfer -Source $DOWNLOAD_URL -Destination $zipPath -ErrorAction Stop
        }
        else {
            # Fallback to WebClient
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($DOWNLOAD_URL, $zipPath)
            if ($webClient) { $webClient.Dispose() }
        }
    }
    catch {
        Write-Error "Failed to download file: $_"
        exit 1
    }

    Write-Host "Extracting binary..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $TMP_DIR -Force

    # Create install directory if it doesn't exist
    if (-not (Test-Path $INSTALL_DIR)) {
       New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    # Move binary to install location
    Write-Host "Installing to $INSTALL_DIR\$BINARY_NAME..." -ForegroundColor Cyan
    $sourceBinary = Join-Path $TMP_DIR $BINARY_NAME
    $destBinary = Join-Path $INSTALL_DIR $BINARY_NAME
    
    Move-Item -Path $sourceBinary -Destination $destBinary -Force

    # Determine which hooks directory to use
    # If core.hooksPath is already set, use that; otherwise use our default
    $currentHooksPath = git config --global core.hooksPath 2>$null
    if ($currentHooksPath) {
        $ACTUAL_HOOKS_DIR = $currentHooksPath
        Write-Host "Using existing git hooks directory: $ACTUAL_HOOKS_DIR" -ForegroundColor Yellow
    }
    else {
        $ACTUAL_HOOKS_DIR = $GLOBAL_HOOKS_DIR
        # Configure git to use global hooks directory
        $globalHooksDirUnix = $GLOBAL_HOOKS_DIR -replace '\\', '/'
        git config --global core.hooksPath $globalHooksDirUnix
        Write-Host "Configured git to use global hooks from: $GLOBAL_HOOKS_DIR" -ForegroundColor Green
    }

    # Create hooks directory if it doesn't exist
    if (-not (Test-Path $ACTUAL_HOOKS_DIR)) {
        New-Item -ItemType Directory -Path $ACTUAL_HOOKS_DIR -Force | Out-Null
    }

    $HOOK_SCRIPT = Join-Path $ACTUAL_HOOKS_DIR "pre-commit"

    # Convert Windows path to Unix-style path for the hook
    $destBinaryUnix = $destBinary -replace '\\', '/'
    $actualHooksDirUnix = $ACTUAL_HOOKS_DIR -replace '\\', '/'
    
    # Create aikido snippet
    $aikidoSnippet = @"
# --- Aikido local scanner ---
[ -x "$destBinaryUnix" ] || { echo "Aikido Local Scanner is missing. Find install instructions at https://help.aikido.dev/code-scanning/local-code-scanning/aikido-secrets-pre-commit-hook"; exit 1; }
REPO_ROOT="`$(git rev-parse --show-toplevel)"
"$destBinaryUnix" pre-commit-scan "`$REPO_ROOT"
# --- End Aikido local scanner ---
"@

    # Check for existing pre-commit hook
    if (Test-Path $HOOK_SCRIPT) {
        $existingContent = Get-Content $HOOK_SCRIPT -Raw
        
        # Check if aikido scanner is already in the hook
        if ($existingContent -match "Aikido local scanner") {
            Write-Host "Aikido scanner already exists in global pre-commit hook. No changes made." -ForegroundColor Yellow
            exit 0
        }
        
        # Append aikido scanner to existing hook
        $hookContent = $existingContent.TrimEnd() + "`n" + $aikidoSnippet
    }
    else {
        Write-Host "Installing global pre-commit hook..." -ForegroundColor Cyan
        
        $hookContent = @"
#!/bin/sh
$aikidoSnippet
"@
    }

    Set-Content -Path $HOOK_SCRIPT -Value $hookContent -NoNewline
    
    Write-Host ""
    Write-Host "Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The aikido-local-scanner binary is installed at: $destBinary" -ForegroundColor White
    Write-Host "The global pre-commit hook is installed at: $HOOK_SCRIPT" -ForegroundColor White
    Write-Host "Git is configured to use global hooks from: $ACTUAL_HOOKS_DIR" -ForegroundColor White
    Write-Host ""
    Write-Host "The hook will now run automatically for all your Git repositories." -ForegroundColor White
}
finally {
    # Cleanup temporary directory
    if (Test-Path $TMP_DIR) {
        Remove-Item -Path $TMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}

