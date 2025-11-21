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
    ORIGINAL_SCRIPT="${SCRIPT_DIR}/uninstall-aikido-hook.sh"
    
    # Create a modified version of the script with lines 11-12 replaced
    UNINSTALL_SCRIPT="${TEST_DIR}/uninstall-aikido-hook-modified.sh"
    {
        head -n 10 "${ORIGINAL_SCRIPT}"
        echo "CURRENT_HOOKS_PATH=${TEST_HOOKS_DIR}"
        tail -n +12 "${ORIGINAL_SCRIPT}"
    } > "${UNINSTALL_SCRIPT}"
    chmod +x "${UNINSTALL_SCRIPT}"
}

# Teardown: Clean up after each test
teardown() {
    rm -rf "${TEST_DIR}"
}

@test "exits successfully when pre-commit hook file does not exist" {
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Pre-commit hook file not found"
}

@test "exits successfully when Aikido snippet is not in hook" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
echo "Some other hook content"
EOF
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Aikido scanner not found in pre-commit hook"
}

@test "exits with error when start marker is missing" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- End Aikido local scanner ---
echo "Malformed hook"
EOF
    run bash "${UNINSTALL_SCRIPT}"
    assert_failure
    assert_output --partial "Start marker not found"
}

@test "exits with error when end marker is missing" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
echo "Aikido content without end marker"
EOF
    run bash "${UNINSTALL_SCRIPT}"
    assert_failure
    assert_output --partial "End marker"
    assert_output --partial "is missing"
}

@test "removes Aikido snippet from hook file with only Aikido content" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
[ -x "/path/to/binary" ] || { echo "Missing"; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel)"
"/path/to/binary" pre-commit-scan "$REPO_ROOT"
# --- End Aikido local scanner ---
EOF
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Removed Aikido snippet"
    
    # Verify the file is empty (except for shebang)
    content=$(cat "${TEST_HOOKS_DIR}/pre-commit")
    assert_equal "$content" "#!/bin/sh"
}

@test "removes Aikido snippet while preserving other hook content" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
echo "Preserved content before hook"
# --- Aikido local scanner ---
[ -x "/path/to/binary" ] || { echo "Missing"; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel)"
"/path/to/binary" pre-commit-scan "$REPO_ROOT"
# --- End Aikido local scanner ---
echo "Preserved content after hook"
EOF
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    
    # Verify Aikido content is removed but other content remains
    content=$(cat "${TEST_HOOKS_DIR}/pre-commit")
    assert_output --partial "Removed Aikido snippet"
    assert_equal "$(echo "$content" | grep -c "Aikido")" "0"
    assert_equal "$(echo "$content" | grep -c "Preserved content before hook")" "1"
    assert_equal "$(echo "$content" | grep -c "Preserved content after hook")" "1"
}

@test "removes binary file when it exists" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
# --- End Aikido local scanner ---
EOF
    echo "fake binary" > "${TEST_INSTALL_DIR}/aikido-local-scanner"
    chmod +x "${TEST_INSTALL_DIR}/aikido-local-scanner"
    
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Removed aikido-local-scanner binary"
    
    # Verify binary is removed
    assert_file_not_exist "${TEST_INSTALL_DIR}/aikido-local-scanner"
}

@test "handles missing binary gracefully" {
    cat > "${TEST_HOOKS_DIR}/pre-commit" << 'EOF'
#!/bin/sh
# --- Aikido local scanner ---
# --- End Aikido local scanner ---
EOF
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    assert_output --partial "Binary not found"
}

@test "handles multiple Aikido sections correctly" {
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
    run bash "${UNINSTALL_SCRIPT}"
    assert_success
    
    # Verify all Aikido sections are removed
    content=$(cat "${TEST_HOOKS_DIR}/pre-commit")
    assert_equal "$(echo "$content" | grep -c "Aikido")" "0"
    assert_equal "$(echo "$content" | grep -c "Between")" "1"
    assert_equal "$(echo "$content" | grep -c "After")" "1"
}

