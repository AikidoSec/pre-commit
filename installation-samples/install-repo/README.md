# Repository Installation

This directory contains scripts to install the Aikido Secrets pre-commit hook for a single Git repository.
These scripts can be committed to your repo, each developer can run it to setup the hook in their repo.

## Available Scripts

### `install-repo.sh` (Bash)
Bash installation script for Linux, Mac or Windows (using Git Bash - comes with Git for Windows) to setup the pre-commit hook for a repo.

Save the script as install-aikido-hook.sh
Make it executable: `chmod +x install-aikido-hook.sh`
Run it from your repository root: `./install-aikido-hook.sh`

### `install-repo.ps1` (PowerShell)
Powershell installation script that can be used on Windows to setup the pre-commit hook for a repo.

Save the script as install-aikido-hook.ps1
Run it from your repository root: `.\install-aikido-hook.ps1`

## What This Does

These scripts download the Aikido pre-commit scanner used for secret detection and install the Aikido Secrets pre-commit hook in the `.git/hooks/` directory of the current repository. The hook will run automatically before each commit to scan for secrets, passwords, and API keys in your staged files.

## Requirements

- Git must be initialized in the repository
- Script must be run from the root of the repository
- Appropriate permissions to write to `.git/hooks/`

## How It Works

1. Downloads and installs the `aikido-local-scanner` binary to `~/.local/bin` (or `%USERPROFILE%\.local\bin` on Windows)
2. Installs the pre-commit hook script in the `.git/hooks/` directory of the current repository.

Once installed, the hook will run automatically before each commit in the repository to scan for secrets, passwords, and API keys in your staged files.