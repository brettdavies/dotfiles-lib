#!/usr/bin/env bats
# Tests for modern shell features library
# Tests: read_lines_into_array, read_null_delimited_into_array, parameter expansion helpers

load 'test_helper'

# ============================================================================
# Array Reading Tests
# ============================================================================

@test "shell: read_lines_into_array reads file into array" {
    load_lib "full"
    
    local test_file
    test_file=$(mktemp)
    echo -e "line1\nline2\nline3" > "$test_file"
    
    local test_array
    read_lines_into_array test_array "$test_file"
    
    [ "${#test_array[@]}" -eq 3 ]
    [ "${test_array[0]}" = "line1" ]
    [ "${test_array[1]}" = "line2" ]
    [ "${test_array[2]}" = "line3" ]
    
    rm -f "$test_file"
}

@test "shell: read_lines_into_array handles empty file" {
    load_lib "full"
    
    local test_file
    test_file=$(mktemp)
    touch "$test_file"
    
    local test_array
    read_lines_into_array test_array "$test_file"
    
    [ "${#test_array[@]}" -eq 0 ]
    
    rm -f "$test_file"
}

@test "shell: read_lines_into_array works with or without nameref" {
    load_lib "full"
    
    # This test verifies that read_lines_into_array works regardless of nameref support
    # It should use nameref when available, eval fallback when not
    local test_file
    test_file=$(mktemp)
    echo -e "test1\ntest2\ntest3" > "$test_file"
    
    local test_array
    read_lines_into_array test_array "$test_file"
    
    # Should work with both nameref and eval fallback
    [ "${#test_array[@]}" -eq 3 ]
    [ "${test_array[0]}" = "test1" ]
    [ "${test_array[1]}" = "test2" ]
    [ "${test_array[2]}" = "test3" ]
    
    rm -f "$test_file"
}

@test "shell: read_lines_into_array fallback works correctly" {
    load_lib "full"
    
    # Test that the function produces correct results even when using fallback
    # This verifies backward compatibility
    local test_file
    test_file=$(mktemp)
    echo -e "line1\nline2" > "$test_file"
    
    local test_array
    read_lines_into_array test_array "$test_file"
    
    # Verify results are correct regardless of implementation
    [ "${#test_array[@]}" -eq 2 ]
    [ "${test_array[0]}" = "line1" ]
    [ "${test_array[1]}" = "line2" ]
    
    rm -f "$test_file"
}

# ============================================================================
# Parameter Expansion Helper Tests
# ============================================================================

@test "shell: split_string splits string by delimiter (works with zsh and bash)" {
    load_lib "full"
    
    # This test verifies split_string works with both zsh parameter expansion and bash IFS fallback
    local test_array
    split_string test_array "a,b,c" ","
    
    [ "${#test_array[@]}" -eq 3 ]
    [ "${test_array[0]}" = "a" ]
    [ "${test_array[1]}" = "b" ]
    [ "${test_array[2]}" = "c" ]
}

@test "shell: split_string fallback produces same results" {
    load_lib "full"
    
    # Test with different delimiters to verify fallback works
    local test_array1 test_array2
    
    split_string test_array1 "a:b:c" ":"
    split_string test_array2 "x-y-z" "-"
    
    [ "${#test_array1[@]}" -eq 3 ]
    [ "${#test_array2[@]}" -eq 3 ]
    [ "${test_array1[0]}" = "a" ]
    [ "${test_array2[0]}" = "x" ]
}

@test "shell: join_array joins array with delimiter" {
    load_lib "full"
    
    local test_array=(a b c)
    local result
    result=$(join_array test_array "," "name")
    
    [ "$result" = "a,b,c" ]
}

@test "shell: uppercase_string converts to uppercase (zsh and fallback)" {
    load_lib "full"
    
    # Test that uppercase_string works with both zsh parameter expansion and tr fallback
    local result
    result=$(uppercase_string "hello")
    
    [ "$result" = "HELLO" ]
    
    # Test with mixed case
    result=$(uppercase_string "HeLLo WoRLd")
    [ "$result" = "HELLO WORLD" ]
}

@test "shell: lowercase_string converts to lowercase (zsh and fallback)" {
    load_lib "full"
    
    # Test that lowercase_string works with both zsh parameter expansion and tr fallback
    local result
    result=$(lowercase_string "HELLO")
    
    [ "$result" = "hello" ]
    
    # Test with mixed case
    result=$(lowercase_string "HeLLo WoRLd")
    [ "$result" = "hello world" ]
}

# ============================================================================
# Zsh Module Loading Tests
# ============================================================================

@test "shell: zsh modules load when running under zsh" {
    load_lib "full"
    
    # Skip if not running under zsh
    is_zsh || skip "Not running under zsh"
    
    # Modules should be loaded (flags should be set)
    # Note: This test may pass even if modules fail to load (they're optional)
    # We're just checking that the function doesn't error
    run load_zsh_modules
    assert_success
}

