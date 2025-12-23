#!/bin/bash

set -e

# Parse arguments
DOWNLOAD_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --download-only)
            DOWNLOAD_ONLY=true
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 [--download-only]" >&2
            exit 1
            ;;
    esac
done

VERSION="v1.0.112"
BASE_URL="https://aikido-local-scanner.s3.eu-west-1.amazonaws.com/${VERSION}"
INSTALL_DIR="${HOME}/.local/bin"
GLOBAL_HOOKS_DIR="${HOME}/.git-hooks"

echo "🔍 Detecting platform and architecture..."

# Detect OS / Arch
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux*)
    case "$ARCH" in
      aarch64|arm64) PLATFORM="linux_ARM64" ;;
      x86_64) PLATFORM="linux_X86_64" ;;
      *) echo "Unsupported Linux architecture: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  Darwin*)
    case "$ARCH" in
      arm64) PLATFORM="darwin_ARM64" ;;
      *) echo "Unsupported macOS architecture: $ARCH" >&2; exit 1 ;;
    esac
    ;;
  MINGW*|MSYS*|CYGWIN*)
    PLATFORM="windows_X86_64"
    ;;
  *)
    echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

DOWNLOAD_URL="${BASE_URL}/${PLATFORM}/aikido-pre-commit-local-scanner.zip"
BINARY_NAME="aikido-local-scanner"

if [ "${PLATFORM}" = "windows_X86_64" ]; then
    BINARY_NAME="${BINARY_NAME}.exe"
fi

echo "📥 Downloading aikido-local-scanner for ${PLATFORM}..."
echo "   URL: ${DOWNLOAD_URL}"

# Create temporary directory
TMP_DIR="$(mktemp -d)"
trap "rm -rf ${TMP_DIR}" EXIT

# Download the zip file
if command -v curl &> /dev/null; then
    curl -L -o "${TMP_DIR}/aikido-local-scanner.zip" "${DOWNLOAD_URL}"
elif command -v wget &> /dev/null; then
    wget -O "${TMP_DIR}/aikido-local-scanner.zip" "${DOWNLOAD_URL}"
else
    echo "❌ Neither curl nor wget found. Please install one of them."
    exit 1
fi

echo "📦 Extracting binary..."
unzip -q "${TMP_DIR}/aikido-local-scanner.zip" -d "${TMP_DIR}"

# Create install directory if it doesn't exist
mkdir -p "${INSTALL_DIR}"

# Move binary to install location
echo "📁 Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
mv "${TMP_DIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

# If download-only mode, exit after installing the binary
if [ "${DOWNLOAD_ONLY}" = true ]; then
    echo "✅ Download complete!"
    echo ""
    echo "The aikido-local-scanner binary is installed at: ${INSTALL_DIR}/${BINARY_NAME}"
    echo ""
    echo "Note: Git hooks were not configured. Use without --download-only to set up hooks."
    exit 0
fi

# Determine which hooks directory to use
# If core.hooksPath is already set, use that; otherwise use our default
CURRENT_HOOKS_PATH="$(git config --global core.hooksPath || echo '')"
if [ -n "${CURRENT_HOOKS_PATH}" ]; then
    ACTUAL_HOOKS_DIR="${CURRENT_HOOKS_PATH}"
    echo "ℹ️  Using existing git hooks directory: ${ACTUAL_HOOKS_DIR}"
else
    ACTUAL_HOOKS_DIR="${GLOBAL_HOOKS_DIR}"
    # Configure git to use global hooks directory
    git config --global core.hooksPath "${GLOBAL_HOOKS_DIR}"
    echo "✅ Configured git to use global hooks from: ${GLOBAL_HOOKS_DIR}"
fi

# Create hooks directory if it doesn't exist
mkdir -p "${ACTUAL_HOOKS_DIR}"
HOOK_SCRIPT="${ACTUAL_HOOKS_DIR}/pre-commit"

AIKIDO_SNIPPET=$(cat << EOF
# --- Aikido local scanner ---
[ -x "${INSTALL_DIR}/${BINARY_NAME}" ] || { echo "Aikido Local Scanner is missing. Find install instructions at https://help.aikido.dev/code-scanning/local-code-scanning/aikido-secrets-pre-commit-hook"; exit 1; }
REPO_ROOT="\$(git rev-parse --show-toplevel)"
"${INSTALL_DIR}/${BINARY_NAME}" pre-commit-scan "\$REPO_ROOT"
# --- End Aikido local scanner ---
EOF
)

# If no hook exists, create a new one
if [ ! -f "${HOOK_SCRIPT}" ]; then
    echo "#!/bin/sh" > "${HOOK_SCRIPT}"
    echo "${AIKIDO_SNIPPET}" >> "${HOOK_SCRIPT}"
    chmod +x "${HOOK_SCRIPT}"

    echo "✅ Installation complete!"
    echo ""
    echo "The aikido-local-scanner binary is installed at: ${INSTALL_DIR}/${BINARY_NAME}"
    echo "The global pre-commit hook is installed at: ${HOOK_SCRIPT}"
    echo "Git is configured to use global hooks from: ${ACTUAL_HOOKS_DIR}"
    echo ""
    echo "The hook will now run automatically for all your Git repositories."
    exit 0
fi

# Hook exists → check if Aikido is already inside
if grep -q "Aikido local scanner" "${HOOK_SCRIPT}"; then
    echo "ℹ️  Aikido scanner already present in global pre-commit hook. No changes made."
    exit 0
fi

# Append Aikido section to existing hook
echo "" >> "${HOOK_SCRIPT}"
echo "${AIKIDO_SNIPPET}" >> "${HOOK_SCRIPT}"
chmod +x "${HOOK_SCRIPT}"

echo "✅ Installation complete!"
echo ""
echo "The aikido-local-scanner binary is installed at: ${INSTALL_DIR}/${BINARY_NAME}"
echo "The global pre-commit hook is installed at: ${HOOK_SCRIPT}"
echo "Git is configured to use global hooks from: ${ACTUAL_HOOKS_DIR}"
echo ""
echo "The hook will now run automatically for all your Git repositories."

