# Test file for uninstall-aikido-hook.ps1
# Requires: Pester (install via: Install-Module -Name Pester -Force -SkipPublisherCheck)

BeforeAll {
    # Get the script directory
    $script:ScriptDir = Split-Path -Parent $PSScriptRoot
    $script:UninstallScript = Join-Path $script:ScriptDir "uninstall-aikido-hook.ps1"
    
    # Create temporary test directories
    $script:TestRoot = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
    $script:TestHome = Join-Path $script:TestRoot "home"
    $script:TestHooksDir = Join-Path $script:TestRoot "hooks"
    $script:TestInstallDir = Join-Path $script:TestHome ".local\bin"
    $script:MockBinDir = Join-Path $script:TestRoot "bin"
    
    New-Item -ItemType Directory -Path $script:TestHome -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestHooksDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestInstallDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:MockBinDir -Force | Out-Null
    
    # Mock environment variables
    $script:OriginalUserProfile = $env:USERPROFILE
    $script:OriginalPath = $env:PATH
    $env:USERPROFILE = $script:TestHome
    $env:PATH = "$script:MockBinDir;$env:PATH"
    
    # Variable to store mocked hooks path for each test
    $script:MockedHooksPath = $null
    
    # Create mock git script (.cmd file for Windows)
    $mockGitCmd = Join-Path $script:MockBinDir "git.cmd"
    $gitCmdContent = @"
@echo off
if "%1"=="config" if "%2"=="--global" if "%3"=="core.hooksPath" (
    if defined MOCKED_HOOKS_PATH (
        echo %MOCKED_HOOKS_PATH%
        exit /b 0
    ) else (
        exit /b 1
    )
) else (
    exit /b 1
)
"@
    Set-Content -Path $mockGitCmd -Value $gitCmdContent
}

AfterAll {
    # Restore original environment
    $env:USERPROFILE = $script:OriginalUserProfile
    $env:PATH = $script:OriginalPath
    
    # Cleanup
    if (Test-Path $script:TestRoot) {
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "Uninstall-Aikido-Hook" {
    BeforeEach {
        # Reset mocked hooks path before each test
        $script:MockedHooksPath = $null
        if (Test-Path env:MOCKED_HOOKS_PATH) {
            Remove-Item env:MOCKED_HOOKS_PATH
        }
        
        # Clean up test files
        if (Test-Path $script:TestHooksDir) {
            Get-ChildItem -Path $script:TestHooksDir -File | Remove-Item -Force
        }
        if (Test-Path $script:TestInstallDir) {
            Get-ChildItem -Path $script:TestInstallDir -File | Remove-Item -Force
        }
    }
    Context "When no global hooks path is configured" {
        It "Should exit successfully with informative message when no global hooks path is configured" {
            $script:MockedHooksPath = $null
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "No global hooks path configured"
        }
    }
    
    Context "When pre-commit hook file does not exist" {
        It "Should exit successfully with informative message when pre-commit hook file does not exist" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "Pre-commit hook file not found"
        }
    }
    
    Context "When Aikido snippet is not in hook" {
        It "Should exit successfully with informative message when Aikido snippet is not in hook" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            Set-Content -Path $hookFile -Value "#!/bin/sh`necho 'Some other hook content'"
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "Aikido scanner not found"
        }
    }
    
    Context "When start marker is missing" {
        It "Should exit with error when start marker is missing" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            Set-Content -Path $hookFile -Value "# --- End Aikido local scanner ---`necho 'Malformed hook'"
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 1
            ($output | Out-String) | Should -Match "Start marker not found"
        }
    }
    
    Context "When end marker is missing" {
        It "Should exit with error when end marker is missing" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            Set-Content -Path $hookFile -Value "# --- Aikido local scanner ---`necho 'Aikido content without end marker'"
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 1
            ($output | Out-String) | Should -Match "End marker"
            ($output | Out-String) | Should -Match "is missing"
        }
    }
    
    Context "When removing Aikido snippet from hook with only Aikido content" {
        It "Should remove the snippet successfully when removing Aikido snippet from hook with only Aikido content" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            $content = @"
#!/bin/sh
# --- Aikido local scanner ---
[ -x "/path/to/binary" ] || { echo "Missing"; exit 1; }
REPO_ROOT="`$(git rev-parse --show-toplevel)"
"/path/to/binary" pre-commit-scan "`$REPO_ROOT"
# --- End Aikido local scanner ---
"@
            Set-Content -Path $hookFile -Value $content
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "Removed Aikido snippet"
            
            # Verify the file only contains shebang
            $remainingContent = Get-Content -Path $hookFile -Raw
            $remainingContent.Trim() | Should -Be "#!/bin/sh"
        }
    }
    
    Context "When removing Aikido snippet while preserving other hook content" {
        It "Should remove only the Aikido section when removing Aikido snippet while preserving other hook content" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            $content = @"
#!/bin/sh
echo "Before Aikido"
# --- Aikido local scanner ---
[ -x "/path/to/binary" ] || { echo "Missing"; exit 1; }
REPO_ROOT="`$(git rev-parse --show-toplevel)"
"/path/to/binary" pre-commit-scan "`$REPO_ROOT"
# --- End Aikido local scanner ---
echo "After Aikido"
"@
            Set-Content -Path $hookFile -Value $content
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "Removed Aikido snippet"
            
            # Verify Aikido content is removed but other content remains
            $remainingContent = Get-Content -Path $hookFile -Raw
            $remainingContent | Should -Not -Match "Aikido local scanner"
            $remainingContent | Should -Match "Before Aikido"
            $remainingContent | Should -Match "After Aikido"
        }
    }
    
    Context "When binary file exists" {
        It "Should remove the binary file when binary file exists" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            $content = @"
#!/bin/sh
# --- Aikido local scanner ---
# --- End Aikido local scanner ---
"@
            Set-Content -Path $hookFile -Value $content
            
            $binaryFile = Join-Path $script:TestInstallDir "aikido-local-scanner.exe"
            Set-Content -Path $binaryFile -Value "fake binary"
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "Removed aikido-local-scanner binary"
            
            # Verify binary is removed
            Test-Path $binaryFile | Should -Be $false
        }
    }
    
    Context "When binary file does not exist" {
        It "Should handle missing binary gracefully when binary file does not exist" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            $content = @"
#!/bin/sh
# --- Aikido local scanner ---
# --- End Aikido local scanner ---
"@
            Set-Content -Path $hookFile -Value $content
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            ($output | Out-String) | Should -Match "Binary not found"
        }
    }
    
    Context "When multiple Aikido sections exist" {
        It "Should remove all Aikido sections when multiple Aikido sections exist" {
            $script:MockedHooksPath = $script:TestHooksDir
            $env:MOCKED_HOOKS_PATH = $script:MockedHooksPath
            $hookFile = Join-Path $script:TestHooksDir "pre-commit"
            $content = @"
#!/bin/sh
# --- Aikido local scanner ---
echo "First Aikido"
# --- End Aikido local scanner ---
echo "Between"
# --- Aikido local scanner ---
echo "Second Aikido"
# --- End Aikido local scanner ---
echo "After"
"@
            Set-Content -Path $hookFile -Value $content
            
            $output = & $script:UninstallScript *>&1
            $LASTEXITCODE | Should -Be 0
            
            # Verify all Aikido sections are removed
            $remainingContent = Get-Content -Path $hookFile -Raw
            $remainingContent | Should -Not -Match "Aikido local scanner"
            $remainingContent | Should -Match "Between"
            $remainingContent | Should -Match "After"
        }
    }
}

