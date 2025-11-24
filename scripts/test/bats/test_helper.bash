#!/usr/bin/env bash
# Test helper functions for BATS tests
# Provides common setup, teardown, and utility functions

# Load BATS helper functions
load '/usr/local/lib/bats-support/load.bash'
load '/usr/local/lib/bats-assert/load.bash'
load '/usr/local/lib/bats-file/load.bash'

# Get the dotfiles directory (assuming tests run from repo root)
# BATS_TEST_FILENAME is set by BATS, fallback to script location
if [ -n "${BATS_TEST_FILENAME:-}" ]; then
    TEST_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
else
    TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
fi
SCRIPTS_DIR="$TEST_ROOT/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"

# Test fixtures directory
TEST_FIXTURES_DIR="$BATS_TEST_TMPDIR/fixtures"

# Setup function run before each test
setup() {
    # Create test fixtures directory
    mkdir -p "$TEST_FIXTURES_DIR"
    
    # Create a temporary home directory for tests
    export TEST_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$TEST_HOME"
    
    # Create a temporary dotfiles directory for tests
    export TEST_DOTFILES="$BATS_TEST_TMPDIR/dotfiles"
    mkdir -p "$TEST_DOTFILES"
    mkdir -p "$TEST_DOTFILES/stow"
    mkdir -p "$TEST_DOTFILES/scripts/lib"
    
    # Copy library files to test directory for isolation
    if [ -d "$LIB_DIR" ]; then
        cp -r "$LIB_DIR"/* "$TEST_DOTFILES/scripts/lib/" 2>/dev/null || true
    fi
    
    # Set up environment variables
    export HOME="$TEST_HOME"
    export DOTFILES_DIR="$TEST_DOTFILES"
    export STOW_DIR="$TEST_DOTFILES/stow"
    export SCRIPTS_DIR="$TEST_DOTFILES/scripts"
    
    # Reset global variables
    unset DRY_RUN VERBOSE SYNC_LOCAL SYNC_MERGE NO_PROGRESS
    unset LOG_FILE LOG_ENABLED
    unset SCRIPT_TEMP_DIR
}

# Teardown function run after each test
teardown() {
    # Cleanup is handled by BATS_TEST_TMPDIR
    true
}

# Source a library file for testing
# Usage: load_lib <library_name>
# Example: load_lib "lib-core"
load_lib() {
    local lib_name="$1"
    local lib_file="$LIB_DIR/$lib_name.sh"
    
    # Most libraries use $(dirname "$0") to find dependencies, but when sourced
    # from BATS, $0 points to the test runner. lib-core.sh uses BASH_SOURCE[0]
    # which works correctly, so we always load it first to set up dependencies.
    # Then we can load the specific library.
    if [ "$lib_name" = "lib-core" ]; then
        # lib-core.sh uses BASH_SOURCE[0] which works correctly when sourced
        source "$lib_file"
    else
        # Ensure lib-core is loaded first (it handles all dependencies correctly)
        if [ -z "${LIB_CORE_LOADED:-}" ]; then
            source "$LIB_DIR/lib-core.sh"
        fi
        
        # Now source the requested library
        # Some libraries still use $(dirname "$0"), so we need to work around that
        # by temporarily changing directory to the lib directory
        local saved_pwd="$PWD"
        (
            cd "$LIB_DIR" || exit 1
            # Create a temporary wrapper that sources the library with correct $0
            # We'll use bash -c with the library file as the script name
            bash -c "source '$lib_file'" "$lib_name.sh"
        )
        # Variables from the subshell won't persist, so we need to source directly
        # Let's try a different approach: source it directly and let it handle dependencies
        # Since lib-core is already loaded, dependencies should be available
        source "$lib_file" 2>&1 || {
            # If that fails, try sourcing from within the lib directory
            cd "$LIB_DIR" && source "./$lib_name.sh" && cd "$saved_pwd"
        }
        cd "$saved_pwd" 2>/dev/null || true
    fi
}

# Mock a command
# Usage: mock_command <command_name> <mock_script>
# Example: mock_command "brew" "echo 'mocked brew'"
mock_command() {
    local cmd="$1"
    local mock_script="$2"
    local mock_path="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$mock_path"
    echo -e "#!/bin/bash\n$mock_script" > "$mock_path/$cmd"
    chmod +x "$mock_path/$cmd"
    export PATH="$mock_path:$PATH"
}

# Create a test file with content
# Usage: create_test_file <path> <content>
# Example: create_test_file "$TEST_HOME/.testrc" "test content"
create_test_file() {
    local file_path="$1"
    local content="${2:-}"
    mkdir -p "$(dirname "$file_path")"
    echo -e "$content" > "$file_path"
}

# Create a test directory structure
# Usage: create_test_structure <base_dir> <structure>
# Example: create_test_structure "$TEST_DOTFILES/stow" "git/dot-gitconfig"
create_test_structure() {
    local base="$1"
    local structure="$2"
    mkdir -p "$base/$structure"
}

# Assert that a file has specific permissions
# Usage: assert_file_permissions <file> <expected_perms>
# Example: assert_file_permissions "$TEST_HOME/.secrets" "600"
assert_file_permissions() {
    local file="$1"
    local expected="$2"
    local actual
    actual=$(stat -f "%OLp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
    if command -v assert_equal &> /dev/null; then
        assert_equal "$actual" "$expected"
    else
        [ "$actual" = "$expected" ] || return 1
    fi
}

# Assert that a symlink exists and points to the correct target
# Usage: assert_symlink <link> <target>
# Example: assert_symlink "$TEST_HOME/.zshrc" "$STOW_DIR/zsh/dot-zshrc"
assert_symlink() {
    local link="$1"
    local target="$2"
    [ -L "$link" ] || return 1
    local actual_target
    actual_target=$(readlink "$link")
    [ "$actual_target" = "$target" ] || return 1
}

# Assert that a file contains specific content
# Usage: assert_file_contains <file> <pattern>
# Example: assert_file_contains "$log_file" "Test message"
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    grep -q "$pattern" "$file" || return 1
}

# Run a function and capture output
# Usage: run_function <function_name> [args...]
# Example: run_function "detect_os"
run_function() {
    local func="$1"
    shift
    run bash -c "source '$LIB_DIR/lib-core.sh' && $func $*"
}

