# Testing the Uninstall Scripts

This directory contains unit tests for the uninstall scripts.

## Bash Script Tests (test_uninstall_aikido_hook.bats)

Tests for `uninstall-aikido-hook.sh` using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

### Prerequisites

Install BATS:
```bash
# macOS
brew install bats-core

# Or via npm
npm install -g bats
```

Install BATS helper libraries (optional but recommended):
```bash
# macOS
brew install bats-support bats-assert bats-file

# Or via git
git clone https://github.com/bats-core/bats-support.git test_helper/bats-support
git clone https://github.com/bats-core/bats-assert.git test_helper/bats-assert
git clone https://github.com/bats-core/bats-file.git test_helper/bats-file
```

### Running the Tests

```bash
cd installation-samples/install-global
bats test_uninstall_aikido_hook.bats
```

## PowerShell Script Tests (test_uninstall_aikido_hook.Tests.ps1)

Tests for `uninstall-aikido-hook.ps1` using [Pester](https://pester.dev/).

### Prerequisites

Install Pester:
```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck
```
