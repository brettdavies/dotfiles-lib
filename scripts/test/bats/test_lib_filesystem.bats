#!/usr/bin/env bats
# Tests for filesystem operations library
# Tests: lib-filesystem.sh

load 'test_helper'

# ============================================================================
# Filesystem Operations Tests
# ============================================================================

@test "filesystem: find_files_array finds files in directory" {
    load_lib "full"
    
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
    load_lib "full"
    
    local test_dir="$BATS_TEST_TMPDIR/testdir"
    mkdir -p "$test_dir/subdir1"
    mkdir -p "$test_dir/subdir2"
    touch "$test_dir/file.txt"
    
    find_dirs_in_dir "$test_dir"
    
    [ "${#FIND_RESULTS[@]}" -ge 2 ]
}

@test "filesystem: count_files_in_dir counts files correctly" {
    load_lib "full"
    
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
    load_lib "full"
    
    local test_dir="$BATS_TEST_TMPDIR/emptydir"
    mkdir -p "$test_dir"
    
    run is_dir_empty "$test_dir"
    assert_success
}

@test "filesystem: is_dir_empty returns false for non-empty directory" {
    load_lib "full"
    
    local test_dir="$BATS_TEST_TMPDIR/nonemptydir"
    mkdir -p "$test_dir"
    touch "$test_dir/file.txt"
    
    run is_dir_empty "$test_dir"
    assert_failure
}

@test "filesystem: clear_dir_cache clears cache" {
    load_lib "full"
    
    init_dir_cache
    run clear_dir_cache
    
    # Cache should be cleared (no way to directly verify, but function should not fail)
    assert_success
}

# ============================================================================
# Zsh Glob Qualifier Tests
# ============================================================================

@test "filesystem: find_files_zsh_glob works under zsh" {
    load_lib "full"
    
    # Skip if not running under zsh
    is_zsh || skip "Not running under zsh"
    
    local test_dir="$BATS_TEST_TMPDIR/zshglob"
    mkdir -p "$test_dir"
    touch "$test_dir/file1.sh"
    touch "$test_dir/file2.sh"
    touch "$test_dir/file3.txt"
    
    run find_files_zsh_glob "$test_dir" "f" "*.sh"
    assert_success
    
    [ "${#FIND_RESULTS[@]}" -ge 2 ]
}

@test "filesystem: find_files_zsh_glob returns empty when not zsh" {
    load_lib "full"
    
    # Skip if running under zsh (this test is for bash)
    is_zsh && skip "Running under zsh, skipping bash fallback test"
    
    local test_dir="$BATS_TEST_TMPDIR/bash_test"
    mkdir -p "$test_dir"
    touch "$test_dir/file1.txt"
    
    # Should return empty array and exit with failure when not zsh
    run find_files_zsh_glob "$test_dir" "f"
    assert_failure
    [ "${#FIND_RESULTS[@]}" -eq 0 ]
}

@test "filesystem: get_dir_listing_zsh works under zsh" {
    load_lib "full"
    
    # Skip if not running under zsh
    is_zsh || skip "Not running under zsh"
    
    local test_dir="$BATS_TEST_TMPDIR/zshlist"
    mkdir -p "$test_dir"
    touch "$test_dir/file1.txt"
    touch "$test_dir/file2.txt"
    mkdir -p "$test_dir/subdir"
    
    run get_dir_listing_zsh "$test_dir" "f"
    assert_success
    
    [ "${#DIR_LISTING[@]}" -ge 2 ]
}

@test "filesystem: find_files_in_dir works with zsh globs or find fallback" {
    load_lib "full"
    
    # This test verifies that find_files_in_dir works correctly whether using
    # zsh glob qualifiers or find command fallback
    local test_dir="$BATS_TEST_TMPDIR/fallback_test"
    mkdir -p "$test_dir"
    touch "$test_dir/test1.txt"
    touch "$test_dir/test2.txt"
    touch "$test_dir/test3.sh"
    
    find_files_in_dir "$test_dir" "-type f"
    
    # Should find files regardless of method used (zsh globs or find)
    [ "${#FIND_RESULTS[@]}" -ge 3 ]
    
    # Verify specific files are found
    local found=false
    for file in "${FIND_RESULTS[@]}"; do
        if [[ "$file" == *"test1.txt" ]]; then
            found=true
            break
        fi
    done
    [ "$found" = true ]
}

@test "filesystem: find_files_in_dir fallback produces correct results" {
    load_lib "full"
    
    # Test that fallback to find command produces same results as zsh globs
    local test_dir="$BATS_TEST_TMPDIR/fallback_verify"
    mkdir -p "$test_dir/subdir"
    touch "$test_dir/file1.txt"
    touch "$test_dir/subdir/file2.txt"
    
    find_files_in_dir "$test_dir" "-type f"
    local count="${#FIND_RESULTS[@]}"
    
    # Should find both files regardless of implementation
    [ "$count" -ge 2 ]
}

