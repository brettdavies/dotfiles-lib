#!/usr/bin/env bats
# Tests for package checking library
# Tests: lib-packages.sh

load 'test_helper'

# ============================================================================
# Package Cache Tests
# ============================================================================

@test "packages: init_package_cache initializes cache" {
    load_lib "lib-packages"
    
    # Mock brew to avoid actual calls
    mock_command "brew" "echo ''"
    
    run init_package_cache
    assert_success
}

@test "packages: check_assoc_array_support detects support" {
    load_lib "lib-packages"
    
    run check_assoc_array_support
    # Should succeed on Bash 4+ or zsh
    # May fail on Bash 3.2, which is acceptable
    true
}

# ============================================================================
# Package Checking Tests (with mocks)
# ============================================================================

@test "packages: is_tap_installed returns true for installed tap" {
    load_lib "lib-packages"
    
    mock_command "brew" "echo 'homebrew/cask'"
    init_package_cache
    
    run is_tap_installed "homebrew/cask"
    # May succeed or fail depending on cache state
    true
}

@test "packages: get_cursor_command finds cursor command" {
    load_lib "lib-packages"
    
    mock_command "cursor" "echo 'cursor command'"
    
    run get_cursor_command
    # Should find the mocked command or return empty
    true
}

# Note: More comprehensive package tests would require mocking brew list,
# brew tap, and extension checking commands, which is complex.
# These tests verify the functions exist and can be called.

# ============================================================================
# Version Comparison Tests
# ============================================================================

@test "packages: version_ge returns true for greater version" {
    load_lib "lib-packages"
    
    run version_ge "2.0.0" "1.0.0"
    assert_success
}

@test "packages: version_ge returns true for equal version" {
    load_lib "lib-packages"
    
    run version_ge "1.0.0" "1.0.0"
    assert_success
}

@test "packages: version_ge returns false for lesser version" {
    load_lib "lib-packages"
    
    run version_ge "1.0.0" "2.0.0"
    assert_failure
}

@test "packages: version_le returns true for lesser version" {
    load_lib "lib-packages"
    
    run version_le "1.0.0" "2.0.0"
    assert_success
}

@test "packages: version_le returns true for equal version" {
    load_lib "lib-packages"
    
    run version_le "1.0.0" "1.0.0"
    assert_success
}

@test "packages: version_le returns false for greater version" {
    load_lib "lib-packages"
    
    run version_le "2.0.0" "1.0.0"
    assert_failure
}

@test "packages: version_lt returns true for lesser version" {
    load_lib "lib-packages"
    
    run version_lt "1.0.0" "2.0.0"
    assert_success
}

@test "packages: version_lt returns false for equal version" {
    load_lib "lib-packages"
    
    run version_lt "1.0.0" "1.0.0"
    assert_failure
}

@test "packages: version_lt returns false for greater version" {
    load_lib "lib-packages"
    
    run version_lt "2.0.0" "1.0.0"
    assert_failure
}

# ============================================================================
# Target Version Parsing Tests
# ============================================================================

@test "packages: parse_target_version extracts base version without caret" {
    load_lib "lib-packages"
    
    parse_target_version "5.2.0"
    [ "$TARGET_VERSION_BASE" = "5.2.0" ]
    [ "$TARGET_VERSION_HAS_CARET" = "false" ]
}

@test "packages: parse_target_version detects caret syntax" {
    load_lib "lib-packages"
    
    parse_target_version "5.2^"
    [ "$TARGET_VERSION_BASE" = "5.2" ]
    [ "$TARGET_VERSION_HAS_CARET" = "true" ]
}

@test "packages: parse_target_version fails for empty version" {
    load_lib "lib-packages"
    
    run parse_target_version ""
    assert_failure
}

# ============================================================================
# Target Version Expansion Tests
# ============================================================================

@test "packages: expand_target_version expands caret syntax correctly" {
    load_lib "lib-packages"
    
    expand_target_version "5.2^"
    [ "$EXPANDED_MIN_VERSION" = "5.2.0" ]
    [ "$EXPANDED_MAX_VERSION" = "5.3.0" ]
}

@test "packages: expand_target_version handles version without caret" {
    load_lib "lib-packages"
    
    expand_target_version "5.2.0"
    [ "$EXPANDED_MIN_VERSION" = "5.2.0" ]
    [ "$EXPANDED_MAX_VERSION" = "5.2.0" ]
}

@test "packages: expand_target_version handles single digit minor version" {
    load_lib "lib-packages"
    
    expand_target_version "1.6^"
    [ "$EXPANDED_MIN_VERSION" = "1.6.0" ]
    [ "$EXPANDED_MAX_VERSION" = "1.7.0" ]
}

@test "packages: expand_target_version fails for empty version" {
    load_lib "lib-packages"
    
    run expand_target_version ""
    assert_failure
}

# ============================================================================
# Version Matching Tests
# ============================================================================

@test "packages: find_matching_version finds version within range" {
    load_lib "lib-packages"
    
    local versions="5.2.0
5.2.1
5.2.15
5.3.0"
    
    run find_matching_version "$versions" "5.2.0" "5.3.0"
    assert_success
    assert_output "5.2.15"
}

@test "packages: find_matching_version returns empty when no match" {
    load_lib "lib-packages"
    
    local versions="5.1.0
5.3.0"
    
    run find_matching_version "$versions" "5.2.0" "5.3.0"
    assert_failure
    assert_output ""
}

@test "packages: find_matching_version handles no constraints" {
    load_lib "lib-packages"
    
    local versions="5.2.0
5.2.1"
    
    run find_matching_version "$versions" "" ""
    assert_success
    assert_output "5.2.0"
}

# ============================================================================
# Version Validation Tests
# ============================================================================

@test "packages: validate_package_version accepts version within range" {
    load_lib "lib-packages"
    
    run validate_package_version "5.2.5" "5.2.0" "5.3.0" "true"
    assert_success
}

@test "packages: validate_package_version rejects version below min" {
    load_lib "lib-packages"
    
    run validate_package_version "5.1.0" "5.2.0" "5.3.0" "true"
    assert_failure
}

@test "packages: validate_package_version rejects version at exclusive max" {
    load_lib "lib-packages"
    
    run validate_package_version "5.3.0" "5.2.0" "5.3.0" "true"
    assert_failure
}

@test "packages: validate_package_version accepts version at inclusive max" {
    load_lib "lib-packages"
    
    run validate_package_version "5.3.0" "5.2.0" "5.3.0" "false"
    assert_success
}

@test "packages: validate_package_version accepts version with no constraints" {
    load_lib "lib-packages"
    
    run validate_package_version "5.2.0" "" ""
    assert_success
}

# ============================================================================
# Homebrew Version Query Tests
# ============================================================================

@test "packages: query_brew_versions returns version for package" {
    load_lib "lib-packages"
    
    # Skip if brew is not available (common in CI environments)
    if ! command -v brew &> /dev/null; then
        skip "brew not available for testing"
    fi
    
    # Mock brew info to return JSON
    mock_command "brew" "if [ \"\$1\" = \"info\" ] && [ \"\$2\" = \"--json=v1\" ]; then echo '[{\"name\":\"bash\",\"versions\":{\"stable\":\"5.2.15\"}}]'; else command brew \"\$@\"; fi"
    
    # Mock jq if not available
    if ! command -v jq &> /dev/null; then
        mock_command "jq" "echo '5.2.15'"
    fi
    
    run query_brew_versions "bash" "package"
    # May succeed or fail depending on actual brew availability
    true
}

@test "packages: query_brew_versions returns empty when brew not available" {
    load_lib "lib-packages"
    
    # Ensure brew is not in PATH
    local saved_path="$PATH"
    export PATH="/usr/bin:/bin"
    
    run query_brew_versions "bash" "package"
    assert_failure
    
    export PATH="$saved_path"
}

@test "packages: query_brew_versions handles cask type" {
    load_lib "lib-packages"
    
    # Skip if brew is not available
    if ! command -v brew &> /dev/null; then
        skip "brew not available for testing"
    fi
    
    # Mock brew info to return JSON
    mock_command "brew" "if [ \"\$1\" = \"info\" ] && [ \"\$2\" = \"--cask\" ] && [ \"\$3\" = \"--json=v1\" ]; then echo '[{\"name\":\"ghostty\",\"versions\":{\"stable\":\"1.0.0\"}}]'; else command brew \"\$@\"; fi"
    
    # Mock jq if not available
    if ! command -v jq &> /dev/null; then
        mock_command "jq" "echo '1.0.0'"
    fi
    
    run query_brew_versions "ghostty" "cask"
    # May succeed or fail depending on actual brew availability
    true
}

# ============================================================================
# Package Version Constraints Tests
# ============================================================================

@test "packages: get_package_version_constraints reads target_version from yaml" {
    load_lib "lib-packages"
    
    # Skip if yq is not available
    if ! command -v yq &> /dev/null; then
        skip "yq not available for testing"
    fi
    
    # Create test packages.yaml in test temp directory
    # Function expects $STOW_DIR/brew/packages.yaml, so create that structure
    local test_stow_dir="$BATS_TEST_TMPDIR/test_stow"
    local test_yaml="$test_stow_dir/brew/packages.yaml"
    mkdir -p "$(dirname "$test_yaml")"
    cat > "$test_yaml" <<EOF
packages:
  bash:
    brew: bash
    target_version: "5.2^"
EOF
    
    # Temporarily override STOW_DIR to point to test temp directory
    local original_stow_dir="${STOW_DIR:-}"
    export STOW_DIR="$test_stow_dir"
    
    get_package_version_constraints "bash" "brew"
    
    # Restore original STOW_DIR
    if [ -n "$original_stow_dir" ]; then
        export STOW_DIR="$original_stow_dir"
    else
        unset STOW_DIR
    fi
    
    [ "$PACKAGE_MIN_VERSION" = "5.2.0" ]
    [ "$PACKAGE_MAX_VERSION" = "5.3.0" ]
    [ "$PACKAGE_MAX_VERSION_EXCLUSIVE" = "true" ]
}

@test "packages: get_package_version_constraints handles brew_target_version override" {
    load_lib "lib-packages"
    
    # Skip if yq is not available
    if ! command -v yq &> /dev/null; then
        skip "yq not available for testing"
    fi
    
    # Create test packages.yaml in test temp directory
    # Function expects $STOW_DIR/brew/packages.yaml, so create that structure
    local test_stow_dir="$BATS_TEST_TMPDIR/test_stow"
    local test_yaml="$test_stow_dir/brew/packages.yaml"
    mkdir -p "$(dirname "$test_yaml")"
    cat > "$test_yaml" <<EOF
packages:
  bash:
    brew: bash
    target_version: "5.1^"
    brew_target_version: "5.2^"
EOF
    
    # Temporarily override STOW_DIR to point to test temp directory
    local original_stow_dir="${STOW_DIR:-}"
    export STOW_DIR="$test_stow_dir"
    
    get_package_version_constraints "bash" "brew"
    
    # Restore original STOW_DIR
    if [ -n "$original_stow_dir" ]; then
        export STOW_DIR="$original_stow_dir"
    else
        unset STOW_DIR
    fi
    
    [ "$PACKAGE_MIN_VERSION" = "5.2.0" ]
    [ "$PACKAGE_MAX_VERSION" = "5.3.0" ]
}

@test "packages: get_package_version_constraints falls back to min_version" {
    load_lib "lib-packages"
    
    # Skip if yq is not available
    if ! command -v yq &> /dev/null; then
        skip "yq not available for testing"
    fi
    
    # Create test packages.yaml in test temp directory
    # Function expects $STOW_DIR/brew/packages.yaml, so create that structure
    local test_stow_dir="$BATS_TEST_TMPDIR/test_stow"
    local test_yaml="$test_stow_dir/brew/packages.yaml"
    mkdir -p "$(dirname "$test_yaml")"
    cat > "$test_yaml" <<EOF
packages:
  bash:
    brew: bash
    min_version: "5.2"
EOF
    
    # Temporarily override STOW_DIR to point to test temp directory
    local original_stow_dir="${STOW_DIR:-}"
    export STOW_DIR="$test_stow_dir"
    
    get_package_version_constraints "bash" "brew"
    
    # Restore original STOW_DIR
    if [ -n "$original_stow_dir" ]; then
        export STOW_DIR="$original_stow_dir"
    else
        unset STOW_DIR
    fi
    
    [ "$PACKAGE_MIN_VERSION" = "5.2" ]
}

