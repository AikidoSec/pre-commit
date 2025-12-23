# Aikido Secrets pre-commit hook

The Aikido Secrets pre-commit hook scans your staged code for secrets, passwords and API keys. It stops sensitive data from ever reaching your repository, which reduces the risk of leaks and accidental exposure.

## Installation

### Option 1: Global Installation

To install and setup the hook globally (applies to all repositories):

**macOS/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/AikidoSec/pre-commit/main/installation-samples/install-global/install-aikido-hook.sh | bash
```

**Windows (PowerShell):**
```powershell
iex (iwr "https://raw.githubusercontent.com/AikidoSec/pre-commit/main/installation-samples/install-global/install-aikido-hook.ps1" -UseBasicParsing)
```

This will download the Aikido Scanner binary and setup a global git pre-commit hook.

### Option 2: Global Installation using Aikido Expansion Packs in IDE

If you are using the [Aikido IDE plugin](https://help.aikido.dev/ide-plugins/ide-plugins-overview) in Visual Studio Code, Cursor, Windsurf, Antigravity, Kiro or any JetBrains IDE,
you can easily setup the Aikido pre-commit hook by using the [Aikido Expansion Packs](https://help.aikido.dev/ide-plugins/features/aikido-expansion-packs).

### Option 3: Pre-commit Framework

If you're already using the [pre-commit](https://pre-commit.com/) framework, add this to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/AikidoSec/pre-commit
    rev: main  # or pin to a specific commit
    hooks:
      - id: aikido-local-scanner
```

Then install the hooks:

```bash
pre-commit install
```

**Note:** The `aikido-local-scanner` binary must be installed separately. Run the global installation script first:

**macOS/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/AikidoSec/pre-commit/518945d243beec968f18c8c0c990f3deda084804/installation-samples/install-global/install-aikido-hook.sh | bash -s -- --download-only
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/AikidoSec/pre-commit/518945d243beec968f18c8c0c990f3deda084804/installation-samples/install-global/install-aikido-hook.ps1 | % { iex \"& { $_ } -DownloadOnly\" }
```

This installs the scanner to `~/.local/bin/aikido-local-scanner`.

## More Information

More info on how to install and use the Aikido Secrets pre-commit hook can be found [here](https://help.aikido.dev/code-scanning/local-code-scanning/aikido-secrets-pre-commit-hook).
