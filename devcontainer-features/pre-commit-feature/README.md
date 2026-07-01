# Aikido Secrets pre-commit hook (aikido-secrets-pre-commit-hook-feature)

The Aikido Secrets pre-commit githook scans your staged code for secrets, passwords and API keys.

The binary is installed system-wide to `/usr/local/bin`, and the hook is registered via `git config --system`, so it applies to every user in the container — including the non-root remote user your dev container runs as.

## Example Usage

```json
"features": {
    "ghcr.io/AikidoSec/pre-commit/aikido-secrets-pre-commit-hook-feature:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of the aikido-local-scanner to install (e.g. `v1.0.129`). Leave empty to use the version pinned by the Feature. | string | (pinned default) |
| setupGlobalHooks | Register the pre-commit hook system-wide. Set to `false` to only install the binary (download-only). | boolean | true |
