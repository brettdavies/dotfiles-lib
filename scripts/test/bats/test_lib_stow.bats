#!/usr/bin/env bats
# Tests for Stow operations library
# Tests: lib-stow.sh

load 'test_helper'

# ============================================================================
# Stow Operations Tests
# ============================================================================

@test "stow: transform_dotfiles_path converts dot- to ." {
    load_lib "lib-stow"
    
    run transform_dotfiles_path "dot-zshrc"
    assert_success
    assert_output ".zshrc"
}

@test "stow: transform_dotfiles_path handles nested paths" {
    load_lib "lib-stow"
    
    run transform_dotfiles_path "config/dot-git/config"
    assert_success
    assert_output "config/.git/config"
}

@test "stow: normalize_path resolves absolute paths" {
    load_lib "lib-stow"
    
    local test_dir="$BATS_TEST_TMPDIR/test"
    mkdir -p "$test_dir"
    
    run normalize_path "$test_dir"
    assert_success
    assert_output "$test_dir"
}

@test "stow: normalize_path resolves relative paths" {
    load_lib "lib-stow"
    
    local test_dir="$BATS_TEST_TMPDIR/test"
    mkdir -p "$test_dir"
    cd "$BATS_TEST_TMPDIR"
    
    run normalize_path "test"
    assert_success
    assert_output "$test_dir"
}

@test "stow: normalize_path handles . and .." {
    load_lib "lib-stow"
    
    local test_dir="$BATS_TEST_TMPDIR/test"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    run normalize_path ".."
    assert_success
    assert_output "$BATS_TEST_TMPDIR"
}

@test "stow: check_dir_symlink detects directory symlink" {
    load_lib "lib-stow"
    
    local target_dir="$BATS_TEST_TMPDIR/target"
    local link_dir="$BATS_TEST_TMPDIR/link"
    mkdir -p "$target_dir"
    ln -s "$target_dir" "$link_dir"
    
    run check_dir_symlink "$link_dir" "$target_dir"
    assert_success
}

@test "stow: is_parent_dir_symlinked detects parent symlink" {
    load_lib "lib-stow"
    
    local target_dir="$BATS_TEST_TMPDIR/target"
    local link_dir="$BATS_TEST_TMPDIR/link"
    local file_in_link="$link_dir/file.txt"
    
    mkdir -p "$target_dir"
    ln -s "$target_dir" "$link_dir"
    touch "$file_in_link"
    
    run is_parent_dir_symlinked "$file_in_link" "$target_dir"
    assert_success
}

