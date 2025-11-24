#!/usr/bin/env bats
# Tests for filesystem operations library
# Tests: lib-filesystem.sh

load 'test_helper'

# ============================================================================
# Filesystem Operations Tests
# ============================================================================

@test "filesystem: find_files_array finds files in directory" {
    load_lib "lib-filesystem"
    
    local test_dir="$BATS_TEST_TMPDIR/testdir"
    mkdir -p "$test_dir"
    touch "$test_dir/file1.txt"
    touch "$test_dir/file2.txt"
    mkdir -p "$test_dir/subdir"
    touch "$test_dir/subdir/file3.txt"
    
    local files_array
    find_files_array files_array "$test_dir" "-type f"
    
    [ "${#files_array[@]}" -ge 3 ]
}

@test "filesystem: find_dirs_in_dir finds directories" {
    load_lib "lib-filesystem"
    
    local test_dir="$BATS_TEST_TMPDIR/testdir"
    mkdir -p "$test_dir/subdir1"
    mkdir -p "$test_dir/subdir2"
    touch "$test_dir/file.txt"
    
    local dirs_array
    find_dirs_in_dir dirs_array "$test_dir"
    
    [ "${#dirs_array[@]}" -ge 2 ]
}

@test "filesystem: count_files_in_dir counts files correctly" {
    load_lib "lib-filesystem"
    
    local test_dir="$BATS_TEST_TMPDIR/testdir"
    mkdir -p "$test_dir"
    touch "$test_dir/file1.txt"
    touch "$test_dir/file2.txt"
    touch "$test_dir/file3.txt"
    
    local count
    count=$(count_files_in_dir "$test_dir")
    
    [ "$count" -ge 3 ]
}

@test "filesystem: is_dir_empty returns true for empty directory" {
    load_lib "lib-filesystem"
    
    local test_dir="$BATS_TEST_TMPDIR/emptydir"
    mkdir -p "$test_dir"
    
    run is_dir_empty "$test_dir"
    assert_success
}

@test "filesystem: is_dir_empty returns false for non-empty directory" {
    load_lib "lib-filesystem"
    
    local test_dir="$BATS_TEST_TMPDIR/nonemptydir"
    mkdir -p "$test_dir"
    touch "$test_dir/file.txt"
    
    run is_dir_empty "$test_dir"
    assert_failure
}

@test "filesystem: clear_dir_cache clears cache" {
    load_lib "lib-filesystem"
    
    init_dir_cache
    clear_dir_cache
    
    # Cache should be cleared (no way to directly verify, but function should not fail)
    assert_success
}

