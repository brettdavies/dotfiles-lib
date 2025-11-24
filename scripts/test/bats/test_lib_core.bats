#!/usr/bin/env bats
# Tests for core library functions
# Tests: lib-constants.sh, lib-os.sh, lib-paths.sh, lib-args.sh, lib-verbose.sh, lib-shell.sh

load 'test_helper'

# ============================================================================
# Constants Tests
# ============================================================================

@test "constants: color constants are defined" {
    load_lib "lib-constants"
    
    [ -n "$RED" ]
    [ -n "$GREEN" ]
    [ -n "$YELLOW" ]
    [ -n "$NC" ]
}

@test "constants: permission constants are defined" {
    load_lib "lib-constants"
    
    [ "$PERM_SECRET_FILE" = "600" ]
    [ "$PERM_SECRET_DIR" = "700" ]
    [ "$PERM_EXECUTABLE" = "755" ]
    [ "$PERM_REGULAR_FILE" = "644" ]
}

# ============================================================================
# OS Detection Tests
# ============================================================================

@test "os: detect_os returns valid OS" {
    load_lib "lib-os"
    
    run detect_os
    assert_success
    case "$output" in
        macos|linux|unknown)
            true
            ;;
        *)
            false
            ;;
    esac
}

@test "os: is_zsh detects zsh correctly" {
    load_lib "lib-os"
    
    # Test when running under zsh
    if [ -n "${ZSH_VERSION:-}" ]; then
        run is_zsh
        assert_success
    else
        # Test when not running under zsh
        run is_zsh
        assert_failure
    fi
}

# ============================================================================
# Path Utilities Tests
# ============================================================================

@test "paths: get_dotfiles_dir returns absolute path" {
    load_lib "lib-paths"
    
    # Test that get_dotfiles_dir returns an absolute path
    local result
    result=$(get_dotfiles_dir)
    [ "${result:0:1}" = "/" ]  # Starts with /
}

@test "paths: DOTFILES_DIR is set after loading lib-paths" {
    load_lib "lib-paths"
    
    [ -n "$DOTFILES_DIR" ]
    [ -d "$DOTFILES_DIR" ]
}

@test "paths: STOW_DIR is set correctly" {
    load_lib "lib-paths"
    
    [ -n "$STOW_DIR" ]
    [ "$STOW_DIR" = "$DOTFILES_DIR/stow" ]
}

@test "paths: SCRIPTS_DIR is set correctly" {
    load_lib "lib-paths"
    
    [ -n "$SCRIPTS_DIR" ]
    [ "$SCRIPTS_DIR" = "$DOTFILES_DIR/scripts" ]
}

@test "paths: OS is set after loading lib-paths" {
    load_lib "lib-paths"
    
    [ -n "${OS:-}" ]
    case "${OS:-}" in
        macos|linux|unknown)
            true
            ;;
        *)
            false
            ;;
    esac
}

# ============================================================================
# Argument Parsing Tests
# ============================================================================

@test "args: parse_common_args sets DRY_RUN flag" {
    load_lib "lib-args"
    
    parse_common_args --dry-run
    [ "$DRY_RUN" = "true" ]
    [ "$VERBOSE" = "false" ]
}

@test "args: parse_common_args sets VERBOSE flag" {
    load_lib "lib-args"
    
    parse_common_args --verbose
    [ "$VERBOSE" = "true" ]
    [ "$DRY_RUN" = "false" ]
}

@test "args: parse_common_args sets VERBOSE flag with -v" {
    load_lib "lib-args"
    
    parse_common_args -v
    [ "$VERBOSE" = "true" ]
}

@test "args: parse_common_args sets SYNC_LOCAL flag" {
    load_lib "lib-args"
    
    parse_common_args --sync-local
    [ "$SYNC_LOCAL" = "true" ]
}

@test "args: parse_common_args sets SYNC_MERGE flag" {
    load_lib "lib-args"
    
    parse_common_args --merge
    [ "$SYNC_MERGE" = "true" ]
}

@test "args: parse_common_args sets NO_PROGRESS flag" {
    load_lib "lib-args"
    
    parse_common_args --no-progress
    [ "$NO_PROGRESS" = "true" ]
}

@test "args: parse_common_args handles multiple flags" {
    load_lib "lib-args"
    
    parse_common_args --dry-run --verbose --sync-local
    [ "$DRY_RUN" = "true" ]
    [ "$VERBOSE" = "true" ]
    [ "$SYNC_LOCAL" = "true" ]
}

@test "args: parse_common_args ignores unknown arguments" {
    load_lib "lib-args"
    
    parse_common_args --unknown-arg --dry-run
    [ "$DRY_RUN" = "true" ]
}

# ============================================================================
# Verbose Output Tests
# ============================================================================

@test "verbose: verbose_found outputs when VERBOSE is true" {
    load_lib "lib-verbose"
    
    VERBOSE=true
    run verbose_found "Test Item"
    assert_success
    assert_output --partial "Test Item: found"
}

@test "verbose: verbose_found does not output when VERBOSE is false" {
    load_lib "lib-verbose"
    
    VERBOSE=false
    run verbose_found "Test Item"
    assert_success
    assert_output ""
}

@test "verbose: verbose_missing outputs when VERBOSE is true" {
    load_lib "lib-verbose"
    
    VERBOSE=true
    run verbose_missing "Test Item"
    assert_success
    assert_output --partial "Test Item: not found"
}

@test "verbose: verbose_would_create outputs when VERBOSE is true" {
    load_lib "lib-verbose"
    
    VERBOSE=true
    run verbose_would_create "~/.testfile"
    assert_success
    assert_output --partial "Would create: ~/.testfile"
}

@test "verbose: verbose_already_exists outputs when VERBOSE is true" {
    load_lib "lib-verbose"
    
    VERBOSE=true
    run verbose_already_exists ".testfile" "permissions: 600"
    assert_success
    assert_output --partial ".testfile already exists"
}

# ============================================================================
# Shell Features Tests
# ============================================================================

@test "shell: read_lines_into_array reads from file" {
    load_lib "lib-shell"
    
    local test_file="$BATS_TEST_TMPDIR/test.txt"
    echo -e "line1\nline2\nline3" > "$test_file"
    
    local test_array
    read_lines_into_array test_array "$test_file"
    
    [ "${#test_array[@]}" -eq 3 ]
    [ "${test_array[0]}" = "line1" ]
    [ "${test_array[1]}" = "line2" ]
    [ "${test_array[2]}" = "line3" ]
}

@test "shell: read_lines_into_array reads from command" {
    load_lib "lib-shell"
    
    local test_array
    read_lines_into_array test_array "echo -e 'line1\nline2'"
    
    [ "${#test_array[@]}" -eq 2 ]
    [ "${test_array[0]}" = "line1" ]
    [ "${test_array[1]}" = "line2" ]
}

@test "shell: read_null_delimited_into_array handles null-delimited input" {
    load_lib "lib-shell"
    
    local test_array
    read_null_delimited_into_array test_array "printf 'file1\0file2\0file3\0'"
    
    [ "${#test_array[@]}" -eq 3 ]
    [ "${test_array[0]}" = "file1" ]
    [ "${test_array[1]}" = "file2" ]
    [ "${test_array[2]}" = "file3" ]
}

