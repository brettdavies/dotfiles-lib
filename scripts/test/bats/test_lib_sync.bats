#!/usr/bin/env bats
# Tests for sync operations library
# Tests: lib-sync.sh

load 'test_helper'

# ============================================================================
# Sync Operations Tests
# ============================================================================

@test "sync: is_binary_file detects binary files" {
    load_lib "full"
    
    # Create a binary file (with null bytes)
    local binary_file="$BATS_TEST_TMPDIR/binary.bin"
    printf '\x00\x01\x02\x03' > "$binary_file"
    
    run is_binary_file "$binary_file"
    assert_success
}

@test "sync: is_binary_file detects text files" {
    load_lib "full"
    
    local text_file="$BATS_TEST_TMPDIR/text.txt"
    echo "This is text" > "$text_file"
    
    run is_binary_file "$text_file"
    assert_failure
}

@test "sync: compare_files detects identical files" {
    load_lib "full"
    
    local file1="$BATS_TEST_TMPDIR/file1.txt"
    local file2="$BATS_TEST_TMPDIR/file2.txt"
    echo "same content" > "$file1"
    echo "same content" > "$file2"
    
    run compare_files "$file1" "$file2"
    assert_success
}

@test "sync: compare_files detects different files" {
    load_lib "full"
    
    local file1="$BATS_TEST_TMPDIR/file1.txt"
    local file2="$BATS_TEST_TMPDIR/file2.txt"
    echo "content 1" > "$file1"
    echo "content 2" > "$file2"
    
    run compare_files "$file1" "$file2"
    assert_failure
}

@test "sync: copy_to_repo copies file correctly" {
    load_lib "full"
    
    local source_file="$BATS_TEST_TMPDIR/source.txt"
    local dest_file="$BATS_TEST_TMPDIR/dest.txt"
    echo "test content" > "$source_file"
    
    run copy_to_repo "$source_file" "$dest_file"
    assert_success
    [ -f "$dest_file" ]
    assert_file_contains "$dest_file" "test content"
}

@test "sync: create_file_backup creates backup" {
    load_lib "full"
    
    local original_file="$BATS_TEST_TMPDIR/original.txt"
    echo "original content" > "$original_file"
    
    local backup_file
    backup_file=$(create_file_backup "$original_file")
    
    [ -f "$backup_file" ]
    assert_file_contains "$backup_file" "original content"
}

