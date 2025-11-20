#!/bin/bash

set -e

INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="aikido-local-scanner"

echo "🔍 Detecting git hooks directory..."

# Determine which hooks directory is being used
CURRENT_HOOKS_PATH="$(git config --global core.hooksPath || echo '')"
if [ -z "${CURRENT_HOOKS_PATH}" ]; then
    echo "ℹ️  No global hooks path configured. Nothing to uninstall."
    exit 0
fi

ACTUAL_HOOKS_DIR="${CURRENT_HOOKS_PATH}"
HOOK_SCRIPT="${ACTUAL_HOOKS_DIR}/pre-commit"

echo "📁 Checking for pre-commit hook at: ${HOOK_SCRIPT}"

# Check if hook file exists
if [ ! -f "${HOOK_SCRIPT}" ]; then
    echo "ℹ️  Pre-commit hook file not found. Nothing to uninstall."
    exit 0
fi

# Check if Aikido snippet exists in the hook
if ! grep -q "Aikido local scanner" "${HOOK_SCRIPT}"; then
    echo "ℹ️  Aikido scanner not found in pre-commit hook. Nothing to uninstall."
    exit 0
fi

# Verify both markers exist before attempting removal
# This prevents accidental deletion if the end marker is missing
HAS_START_MARKER=$(grep -c "^# --- Aikido local scanner ---$" "${HOOK_SCRIPT}" || echo "0")
HAS_END_MARKER=$(grep -c "^# --- End Aikido local scanner ---$" "${HOOK_SCRIPT}" || echo "0")

if [ "${HAS_START_MARKER}" -eq 0 ]; then
    echo "⚠️  Warning: Start marker not found. Aikido section may be malformed."
    echo "   Aborting uninstall - please manually clean up the hook file."
    exit 1
fi

if [ "${HAS_END_MARKER}" -eq 0 ]; then
    echo "⚠️  Error: End marker '# --- End Aikido local scanner ---' is missing!"
    echo "   Aborting uninstall - please manually clean up the hook file."
    exit 1
fi

echo "🗑️  Removing Aikido snippet from pre-commit hook..."

# Use awk to remove only the Aikido section (between the markers)
# This is strict: only removes content between the exact markers
# Read the cleaned content into a variable, then write it back
CLEANED_CONTENT=$(awk '
    /^# --- Aikido local scanner ---$/ {
        in_aikido = 1
        next
    }
    /^# --- End Aikido local scanner ---$/ {
        in_aikido = 0
        next
    }
    !in_aikido {
        print
    }
' "${HOOK_SCRIPT}")

# Write the cleaned content back to the file
echo "${CLEANED_CONTENT}" > "${HOOK_SCRIPT}"
echo "✅ Removed Aikido snippet from pre-commit hook."

# Clean up the binary
BINARY_PATH="${INSTALL_DIR}/${BINARY_NAME}"
if [ -f "${BINARY_PATH}" ]; then
    echo "🗑️  Removing binary from ${BINARY_PATH}..."
    rm -f "${BINARY_PATH}"
    echo "✅ Removed aikido-local-scanner binary."
else
    echo "ℹ️  Binary not found at ${BINARY_PATH} (may have been removed already)."
fi

echo ""
echo "✅ Uninstallation complete!"
echo ""
echo "Note: Git hook configuration (core.hooksPath) was not modified."
echo "      If you want to remove it, run: git config --global --unset core.hooksPath"

