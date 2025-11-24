#!/usr/bin/env bats
# Tests for file operations library
# Tests: lib-file.sh

load 'test_helper'

# ============================================================================
# File Operations Tests
# ============================================================================

@test "file: get_file_permissions returns octal permissions" {
    load_lib "lib-file"
    
    local test_file="$BATS_TEST_TMPDIR/test.txt"
    touch "$test_file"
    chmod 644 "$test_file"
    
    run get_file_permissions "$test_file"
    assert_success
    assert_output "644"
}

@test "file: get_file_permissions handles 600 permissions" {
    load_lib "lib-file"
    
    local test_file="$BATS_TEST_TMPDIR/test.txt"
    touch "$test_file"
    chmod 600 "$test_file"
    
    run get_file_permissions "$test_file"
    assert_success
    assert_output "600"
}

@test "file: get_file_permissions handles 755 permissions" {
    load_lib "lib-file"
    
    local test_file="$BATS_TEST_TMPDIR/test.txt"
    touch "$test_file"
    chmod 755 "$test_file"
    
    run get_file_permissions "$test_file"
    assert_success
    assert_output "755"
}

@test "file: get_file_permissions works cross-platform" {
    load_lib "lib-file"
    
    local test_file="$BATS_TEST_TMPDIR/test.txt"
    touch "$test_file"
    chmod 700 "$test_file"
    
    run get_file_permissions "$test_file"
    assert_success
    # Should work on both macOS (stat -f) and Linux (stat -c)
    assert_output "700"
}

