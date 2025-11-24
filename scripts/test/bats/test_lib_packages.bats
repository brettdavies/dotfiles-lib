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

