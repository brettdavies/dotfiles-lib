#!/usr/bin/env bats
# Standalone tests for package version constraints
# Tests: get_package_version_constraints function

load 'test_helper'

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
    
    echo "=== Test Setup ===" >&2
    echo "STOW_DIR: $STOW_DIR" >&2
    echo "Test YAML file: $test_yaml" >&2
    echo "YAML contents:" >&2
    cat "$test_yaml" >&2
    
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
    
    echo "=== Function Results ===" >&2
    echo "PACKAGE_MIN_VERSION: [$PACKAGE_MIN_VERSION]" >&2
    echo "PACKAGE_MAX_VERSION: [$PACKAGE_MAX_VERSION]" >&2
    echo "PACKAGE_MAX_VERSION_EXCLUSIVE: [$PACKAGE_MAX_VERSION_EXCLUSIVE]" >&2
    
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
    
    echo "=== Test Setup ===" >&2
    echo "STOW_DIR: $STOW_DIR" >&2
    echo "Test YAML file: $test_yaml" >&2
    echo "YAML contents:" >&2
    cat "$test_yaml" >&2
    
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
    
    echo "=== Function Results ===" >&2
    echo "PACKAGE_MIN_VERSION: [$PACKAGE_MIN_VERSION]" >&2
    echo "PACKAGE_MAX_VERSION: [$PACKAGE_MAX_VERSION]" >&2
    echo "PACKAGE_MAX_VERSION_EXCLUSIVE: [$PACKAGE_MAX_VERSION_EXCLUSIVE]" >&2
    
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
    
    echo "=== Test Setup ===" >&2
    echo "STOW_DIR: $STOW_DIR" >&2
    echo "Test YAML file: $test_yaml" >&2
    echo "YAML contents:" >&2
    cat "$test_yaml" >&2
    
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
    
    echo "=== Function Results ===" >&2
    echo "PACKAGE_MIN_VERSION: [$PACKAGE_MIN_VERSION]" >&2
    echo "PACKAGE_MAX_VERSION: [$PACKAGE_MAX_VERSION]" >&2
    echo "PACKAGE_MAX_VERSION_EXCLUSIVE: [$PACKAGE_MAX_VERSION_EXCLUSIVE]" >&2
    
    [ "$PACKAGE_MIN_VERSION" = "5.2" ]
}

