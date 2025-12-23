#!/usr/bin/env python3
"""
Wrapper script for aikido-local-scanner pre-commit hook.
This script is called by the pre-commit framework.
Works on Windows, macOS, and Linux.
"""

import os
import subprocess
import sys
from pathlib import Path


def find_scanner():
    """Find the aikido-local-scanner binary."""
    import shutil

    if sys.platform == "win32":
        binary_name = "aikido-local-scanner.exe"
    else:
        binary_name = "aikido-local-scanner"

    # Check if it's in PATH
    found = shutil.which(binary_name)
    if found:
        return found

    # Check default install location
    install_dir = Path.home() / ".local" / "bin"
    scanner_path = install_dir / binary_name
    if scanner_path.is_file() and os.access(scanner_path, os.X_OK):
        return str(scanner_path)

    return None


def get_repo_root():
    """Get the git repository root directory."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        print("❌ Failed to determine git repository root.", file=sys.stderr)
        sys.exit(1)


def main():
    scanner = find_scanner()

    if not scanner:
        print("❌ aikido-local-scanner not found.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Please install the Aikido scanner first:", file=sys.stderr)
        print("", file=sys.stderr)

        if sys.platform == "win32":
            print(
                "  PowerShell: irm https://raw.githubusercontent.com/AikidoSec/pre-commit/518945d243beec968f18c8c0c990f3deda084804/installation-samples/install-global/install-aikido-hook.ps1 | % { iex \"& { $_ } -DownloadOnly\" }",
                file=sys.stderr,
            )
        else:
            print(
                "  curl -fsSL https://raw.githubusercontent.com/AikidoSec/pre-commit/518945d243beec968f18c8c0c990f3deda084804/installation-samples/install-global/install-aikido-hook.sh | bash -s -- --download-only",
                file=sys.stderr,
            )

        print("", file=sys.stderr)
        print(
            "Or download manually from: https://help.aikido.dev/code-scanning/local-code-scanning/aikido-secrets-pre-commit-hook and place the binary in ~/.local/bin",
            file=sys.stderr,
        )
        sys.exit(1)

    repo_root = get_repo_root()

    # Run the scanner
    try:
        result = subprocess.run([scanner, "pre-commit-scan", repo_root])
        sys.exit(result.returncode)
    except FileNotFoundError:
        print(f"❌ Failed to execute scanner: {scanner}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == "__main__":
    main()

