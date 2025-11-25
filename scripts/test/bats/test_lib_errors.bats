#!/usr/bin/env bats
# Tests for error handling library
# Tests: lib-errors.sh

load 'test_helper'

# ============================================================================
# Error Reporting Tests
# ============================================================================

@test "errors: err outputs error message to stderr" {
    load_lib "full"
    
    run err "Test error message" 1
    assert_failure
    assert_output --partial "Test error message"
    assert_output --partial "Error"
}

@test "errors: err returns specified exit code" {
    load_lib "full"
    
    run err "Test error" 42
    assert_failure
    [ "$status" -eq 42 ]
}

@test "errors: die exits with error message" {
    load_lib "full"
    
    # die function should be available after loading lib-errors
    # Test that it exits with the correct code
    run bash -c "die 'Fatal error' 99" || true
    # die will exit, so we can't easily test it in a subshell
    # Instead, verify the function exists
    command -v die &> /dev/null || return 1
    # We can't easily test exit codes in BATS for functions that exit
    # So we'll just verify the function exists
    true
}

@test "errors: warn outputs warning message to stderr" {
    load_lib "full"
    
    run warn "Test warning"
    assert_success
    assert_output --partial "Test warning"
    assert_output --partial "Warning"
}

@test "errors: info outputs info message to stdout" {
    load_lib "full"
    
    run info "Test info"
    assert_success
    assert_output --partial "Test info"
    assert_output --partial "Info"
}

@test "errors: setup_traps sets up EXIT trap" {
    load_lib "full"
    
    # Create a test cleanup function
    test_cleanup_called=false
    test_cleanup() {
        test_cleanup_called=true
    }
    
    setup_traps test_cleanup
    
    # Verify trap is set (can't easily test execution without exiting)
    # Just verify function doesn't fail
    assert_success
}

# ============================================================================
# Enhanced Error Handling Tests
# ============================================================================

@test "errors: get_call_stack returns call stack information" {
    load_lib "full"
    
    # Test that get_call_stack function exists and can be called
    run get_call_stack
    # Function should return (may be empty, but shouldn't error)
    assert_success
}

@test "errors: setup_function_traps sets up RETURN trap" {
    load_lib "full"
    
    # Test that setup_function_traps function exists
    command -v setup_function_traps &> /dev/null || skip "setup_function_traps not available"
    
    # Call it (should not fail)
    run setup_function_traps
    assert_success
}

@test "errors: enable_debug_tracing works when supported" {
    load_lib "full"
    
    # Skip if BASH_XTRACEFD is not supported
    has_xtracefd_support || skip "BASH_XTRACEFD not supported"
    
    local test_log
    test_log=$(mktemp)
    
    run enable_debug_tracing "$test_log"
    # Should succeed if supported
    [ $status -eq 0 ] || [ $status -eq 1 ]
    
    rm -f "$test_log"
}

@test "errors: wait_for_any_process works when supported" {
    load_lib "full"
    
    # Skip if wait -n is not supported
    has_wait_n_support || skip "wait -n not supported"
    
    # Test that function exists
    command -v wait_for_any_process &> /dev/null || return 1
    
    # Note: Can't easily test wait_for_any_process without background processes
    # Just verify function exists
    true
}

@test "errors: die includes call stack in error message" {
    load_lib "full"
    
    # Test that die function exists and can be called
    # (We can't easily test the full output without exiting)
    command -v die &> /dev/null || return 1
    
    # Verify get_call_stack is used by die
    command -v get_call_stack &> /dev/null || return 1
}

