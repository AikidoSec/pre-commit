#!/bin/bash
set -euo pipefail

# Feature options arrive as uppercased env vars (see devcontainer-feature.json).
VERSION="${VERSION:-}"
SETUP_GLOBAL_HOOKS="${SETUPGLOBALHOOKS:-true}"

# Version installed when the `version` option is left empty.
# Bump this to the latest release on each update — keep it in sync with the
# VERSION pin in installation-samples/install-global/install-aikido-hook.sh.
FALLBACK_VERSION="v1.0.129"

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="aikido-local-scanner"
SYSTEM_HOOKS_DIR="/etc/git-hooks"

log() { echo "🔹 $*"; }

# --- Dependencies ------------------------------------------------------------
# Feature runs before the user's tools are guaranteed present. Install what we
# need on apt-based images; on others, require the tools to already exist.
ensure_dependencies() {
    local missing=()
    for tool in curl unzip git; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    [ ${#missing[@]} -eq 0 ] && return 0

    if command -v apt-get >/dev/null 2>&1; then
        log "Installing missing dependencies: ${missing[*]}"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends "${missing[@]}"
        rm -rf /var/lib/apt/lists/*
    else
        echo "❌ Missing required tools (${missing[*]}) and no apt-get to install them." >&2
        echo "   Install them via your base image or another Feature and retry." >&2
        exit 1
    fi
}

# --- Version resolution ------------------------------------------------------
resolve_version() {
    # Fall back to the pinned default when no explicit version is requested.
    [ -n "$VERSION" ] || VERSION="$FALLBACK_VERSION"
    # Normalize to the vX.Y.Z form the S3 bucket expects.
    [[ "$VERSION" =~ ^v ]] || VERSION="v${VERSION}"
}

# --- Platform detection ------------------------------------------------------
# Features only ever execute inside a Linux container, so we intentionally do
# not carry the darwin/windows branches of the global script.
detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    if [ "$os" != "Linux" ]; then
        echo "❌ Unsupported OS for a dev container Feature: $os" >&2
        exit 1
    fi

    case "$arch" in
        x86_64)         PLATFORM="linux_X86_64" ;;
        aarch64|arm64)  PLATFORM="linux_ARM64" ;;
        *) echo "❌ Unsupported architecture: $arch" >&2; exit 1 ;;
    esac
}

# --- Binary install ----------------------------------------------------------
install_binary() {
    local base_url download_url tmp_dir
    base_url="https://aikido-local-scanner.s3.eu-west-1.amazonaws.com/${VERSION}"
    download_url="${base_url}/${PLATFORM}/aikido-pre-commit-local-scanner.zip"

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    log "Downloading ${BINARY_NAME} ${VERSION} (${PLATFORM})..."
    if ! curl -fsSL -o "${tmp_dir}/scanner.zip" "$download_url"; then
        echo "❌ Failed to download from ${download_url}" >&2
        exit 1
    fi

    unzip -q "${tmp_dir}/scanner.zip" -d "$tmp_dir"
    install -m 0755 "${tmp_dir}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    log "Installed to ${INSTALL_DIR}/${BINARY_NAME}"
}

# --- Hook registration (the part neither existing setup gets right) ----------
configure_hooks() {
    # Respect an existing system-level hooks path rather than overriding it.
    local existing hooks_dir
    existing="$(git config --system --get core.hooksPath 2>/dev/null || true)"
    if [ -n "$existing" ]; then
        hooks_dir="$existing"
        log "Using existing system hooks path: ${hooks_dir}"
    else
        hooks_dir="$SYSTEM_HOOKS_DIR"
        git config --system core.hooksPath "$hooks_dir"
        log "Set system-wide core.hooksPath to ${hooks_dir}"
    fi

    # World-readable/executable so every container user can run the hook.
    mkdir -p "$hooks_dir"
    chmod 755 "$hooks_dir"
    local hook="${hooks_dir}/pre-commit"

    local snippet
    snippet="$(cat <<EOF
# --- Aikido local scanner ---
[ -x "${INSTALL_DIR}/${BINARY_NAME}" ] || { echo "Aikido Local Scanner is missing. Find install instructions at https://help.aikido.dev/code-scanning/local-code-scanning/aikido-secrets-pre-commit-hook"; exit 1; }
REPO_ROOT="\$(git rev-parse --show-toplevel)"
"${INSTALL_DIR}/${BINARY_NAME}" pre-commit-scan "\$REPO_ROOT"
# --- End Aikido local scanner ---
EOF
)"

    if [ -f "$hook" ]; then
        if grep -q "Aikido local scanner" "$hook"; then
            log "Aikido hook already present, skipping."
            chmod 755 "$hook"
            return 0
        fi
        log "Appending Aikido hook to existing pre-commit hook."
        printf '\n%s\n' "$snippet" >> "$hook"
    else
        log "Creating pre-commit hook."
        printf '#!/bin/sh\n%s\n' "$snippet" > "$hook"
    fi
    chmod 755 "$hook"
}

# --- Main --------------------------------------------------------------------
ensure_dependencies
resolve_version
detect_platform
install_binary

if [ "$SETUP_GLOBAL_HOOKS" = "true" ]; then
    configure_hooks
else
    log "setupGlobalHooks=false — binary installed, hook not configured."
fi

echo "✅ Aikido pre-commit Feature installed (${BINARY_NAME} ${VERSION})."
