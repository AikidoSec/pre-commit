#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-file/load'

# Setup: Create temporary directories and files before each test
setup() {
    # Create temporary directories
    TEST_DIR=$(mktemp -d)
    TEST_HOME="${TEST_DIR}/home"
    TEST_HOOKS_DIR="${TEST_DIR}/hooks"
    TEST_INSTALL_DIR="${TEST_HOME}/.local/bin"
    
    mkdir -p "${TEST_HOME}"
    mkdir -p "${TEST_HOOKS_DIR}"
    mkdir -p "${TEST_INSTALL_DIR}"
    
    # Override HOME for testing
    export HOME="${TEST_HOME}"
    
    # Path to the script being tested
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    UNINSTALL_SCRIPT="${SCRIPT_DIR}/uninstall-aikido-hook.sh"
    
    # Mock git config command
    # Use absolute path to ensure we control which git is used
    mkdir -p "${TEST_DIR}/bin"
    cat > "${TEST_DIR}/bin/git" << 'EOFMOCK'
#!/bin/sh
# Mock git command for testing
# Only handle the specific command we need: git config --global core.hooksPath
if [ "$1" = "config" ] && [ "$2" = "--global" ] && [ "$3" = "core.hooksPath" ]; then
    # Read GIT_HOOKS_PATH from environment and output it
    # If empty, exit with non-zero to simulate no config set
    if [ -n "${GIT_HOOKS_PATH}" ]; then
        echo "${GIT_HOOKS_PATH}"
        exit 0
    else
        exit 1
    fi
fi
# For any other git command, fail to prevent accidental real git usage
exit 1
EOFMOCK
    chmod +x "${TEST_DIR}/bin/git"
    
    # Prepend to PATH to ensure our mock is found first
    # Use absolute path to be extra safe
    export PATH="${TEST_DIR}/bin:${PATH}"
    
    # Verify the mock is in PATH and executable
    if ! command -v git >/dev/null 2>&1 || [ "$(command -v git)" != "${TEST_DIR}/bin/git" ]; then
        echo "Warning: Mock git may not be in PATH correctly" >&2
        echo "Expected: ${TEST_DIR}/bin/git" >&2
        echo "Found: $(command -v git 2>/dev/null || echo 'not found')" >&2
    fi
}

# Teardown: Clean up after each test
teardown() {
    rm -rf "${TEST_DIR}"
    unset GIT_HOOKS_PATH
}

@test "mock git command is working" {
    # Verify our mock git is being used
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    run git config --global core.hooksPath
    assert_success
    assert_output "${TEST_HOOKS_DIR}"
}

@test "exits successfully when no global hooks path is configured" {
    GIT_HOOKS_PATH=""
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "No global hooks path configured"
}

@test "exits successfully when pre-commit hook file does not exist" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Pre-commit hook file not found"
}

@test "exits successfully when Aikido snippet is not in hook" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
echo "Some other hook content"
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Aikido scanner not found in pre-commit hook"
}

@test "exits with error when start marker is missing" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- End Aikido local scanner ---
echo "Malformed hook"
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_failure
    assert_output --partial "Start marker not found"
}

@test "exits with error when end marker is missing" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
echo "Aikido content without end marker"
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_failure
    assert_output --partial "End marker"
    assert_output --partial "is missing"
}

@test "removes Aikido snippet from hook file with only Aikido content" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
[ -x "/path/to/binary" ] || { echo "Missing"; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel)"
"/path/to/binary" pre-commit-scan "$REPO_ROOT"
# --- End Aikido local scanner ---
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Removed Aikido snippet"
    
    # Verify the file is empty (except for shebang)
    content=$(cat "${TEST_HOOKS_DIR}/pre-commit")
    assert_equal "$content" "#!/bin/sh"
}

@test "removes Aikido snippet while preserving other hook content" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
echo "Before Aikido"
# --- Aikido local scanner ---
[ -x "/path/to/binary" ] || { echo "Missing"; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel)"
"/path/to/binary" pre-commit-scan "$REPO_ROOT"
# --- End Aikido local scanner ---
echo "After Aikido"
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    
    # Verify Aikido content is removed but other content remains
    content=$(cat "${TEST_HOOKS_DIR}/pre-commit")
    assert_output --partial "Removed Aikido snippet"
    assert_equal "$(echo "$content" | grep -c "Aikido")" "0"
    assert_equal "$(echo "$content" | grep -c "Before Aikido")" "1"
    assert_equal "$(echo "$content" | grep -c "After Aikido")" "1"
}

@test "removes binary file when it exists" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
# --- End Aikido local scanner ---
EOF
    echo "fake binary" > "${TEST_INSTALL_DIR}/aikido-local-scanner"
    chmod +x "${TEST_INSTALL_DIR}/aikido-local-scanner"
    
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Removed aikido-local-scanner binary"
    
    # Verify binary is removed
    assert_file_not_exist "${TEST_INSTALL_DIR}/aikido-local-scanner"
}

@test "handles missing binary gracefully" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
# --- End Aikido local scanner ---
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Binary not found"
}

@test "handles multiple Aikido sections correctly" {
    GIT_HOOKS_PATH="${TEST_HOOKS_DIR}"
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
echo "First Aikido"
# --- End Aikido local scanner ---
echo "Between"
# --- Aikido local scanner ---
echo "Second Aikido"
# --- End Aikido local scanner ---
echo "After"
EOF
    # Explicitly set PATH to ensure mock is used
    run env PATH="${TEST_DIR}/bin:${PATH}" bash "${UNINSTALL_SCRIPT}"
    assert_success
    
    # Verify all Aikido sections are removed
    content=$(cat "${TEST_HOOKS_DIR}/pre-commit")
    assert_equal "$(echo "$content" | grep -c "Aikido")" "0"
    assert_equal "$(echo "$content" | grep -c "Between")" "1"
    assert_equal "$(echo "$content" | grep -c "After")" "1"
}

