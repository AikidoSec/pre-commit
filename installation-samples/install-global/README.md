# Global Installation

This directory contains scripts to install the Aikido Secrets pre-commit hook globally for all Git repositories on your system.
Once installed, the hook will automatically run for all your Git repositories without needing to install it per repository.

## Available Scripts

### `install-aikido-hook.sh` (Bash)
Bash installation script for Linux, Mac or Windows (using Git Bash - comes with Git for Windows) to setup the pre-commit hook globally.

Save the script as install-aikido-hook.sh
Make it executable: `chmod +x install-aikido-hook.sh`
Run it from anywhere: `./install-aikido-hook.sh`

### `install-aikido-hook.ps1` (PowerShell)
PowerShell installation script that can be used on Windows to setup the pre-commit hook globally.

Save the script as install-aikido-hook.ps1
Run it from anywhere: `.\install-aikido-hook.ps1`

## What This Does

These scripts download the Aikido pre-commit scanner used for secret detection and install the Aikido Secrets pre-commit hook in a global Git hooks directory (`~/.git-hooks` on Unix-like systems, `%USERPROFILE%\.git-hooks` on Windows). The script also configures Git to use this global hooks directory via `git config --global core.hooksPath`.

The hook will run automatically before each commit in any Git repository to scan for secrets, passwords, and API keys in your staged files.

## Requirements

- Git must be installed
- Script can be run from any directory (does not need to be in a Git repository)
- Appropriate permissions to write to the global hooks directory and configure Git settings

## How It Works

1. Downloads and installs the `aikido-local-scanner` binary to `~/.local/bin` (or `%USERPROFILE%\.local\bin` on Windows)
2. Creates a global hooks directory at `~/.git-hooks` (or `%USERPROFILE%\.git-hooks` on Windows)
3. Installs the pre-commit hook script in the global hooks directory
4. Configures Git to use the global hooks directory with `git config --global core.hooksPath`

Once installed, the hook will automatically run for all Git repositories on your system. The hook script detects the repository root dynamically, so it works regardless of where you run `git commit`.

## Interaction with repository-local hooks

Git treats `core.hooksPath` as a **replacement** for `.git/hooks`, not an addition to it. Once it is set, Git stops looking in `.git/hooks` entirely for every repository on the machine.

- **`pre-commit` is chained.** The installed hook looks up the repository's own `.git/hooks/pre-commit` and runs it first, then runs the Aikido scan. Repository-local pre-commit hooks — including those installed by the [pre-commit framework](https://pre-commit.com) — keep working. A local hook that fails blocks the commit and the scan does not run. Because the local hook runs first, any file it reformats or re-stages is what the scan sees.

## Uninstalling

To uninstall the global hook:

1. Remove the global hooks directory:
   - Unix/Linux/macOS: `rm -rf ~/.git-hooks`
   - Windows: `Remove-Item -Recurse -Force $env:USERPROFILE\.git-hooks`

2. Reset Git's hooks path:
   ```bash
   git config --global --unset core.hooksPath
   ```

3. Optionally remove the binary:
   - Unix/Linux/macOS: `rm ~/.local/bin/aikido-local-scanner`
   - Windows: `Remove-Item $env:USERPROFILE\.local\bin\aikido-local-scanner.exe`

