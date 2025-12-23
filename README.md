# Aikido Secrets pre-commit hook

The Aikido Secrets pre-commit hook scans your staged code for secrets, passwords and API keys. It stops sensitive data from ever reaching your repository, which reduces the risk of leaks and accidental exposure.

## Installation

### Option 1: Pre-commit Framework

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

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/AikidoSec/pre-commit/main/installation-samples/install-global/install-aikido-hook.sh | bash
```

This installs the scanner to `~/.local/bin/aikido-local-scanner`.

### Option 2: Global Installation

To install the hook globally (applies to all repositories):

**macOS/Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/AikidoSec/pre-commit/main/installation-samples/install-global/install-aikido-hook.sh | bash
```

**Windows (PowerShell):**
```powershell
iex (iwr "https://raw.githubusercontent.com/AikidoSec/pre-commit/main/installation-samples/install-global/install-aikido-hook.ps1" -UseBasicParsing)
```

## More Information

More info on how to install and use the Aikido Secrets pre-commit hook can be found [here](https://help.aikido.dev/code-scanning/local-code-scanning/aikido-secrets-pre-commit-hook).
