#!/bin/bash

# Check if core.hooksPath is set
HOOKS_PATH="$(git config --global core.hooksPath || echo '')"

if [ -z "${HOOKS_PATH}" ]; then
    echo "❌ core.hooksPath is not set"
    exit 1
fi

echo "✅ core.hooksPath is set to: ${HOOKS_PATH}"

# Check if pre-commit hook exists
HOOK_SCRIPT="${HOOKS_PATH}/pre-commit"
if [ ! -f "${HOOK_SCRIPT}" ]; then
    echo "❌ Pre-commit hook file not found at: ${HOOK_SCRIPT}"
    exit 1
fi

# Check if aikido-local-scanner is mentioned in the hook
if ! grep -q "aikido-local-scanner" "${HOOK_SCRIPT}"; then
    echo "❌ aikido-local-scanner not found in pre-commit hook"
    exit 1
fi

echo "✅ aikido-local-scanner found in pre-commit hook"
echo ""
echo "✅ Verification complete: Aikido pre-commit hook is installed"

