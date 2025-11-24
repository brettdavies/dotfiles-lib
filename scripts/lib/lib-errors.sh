#!/usr/bin/env bash
# Error handling and reporting functions
# Provides functions for error reporting, warnings, and trap handlers
# Requires: lib-core.sh (for colors)

# Prevent re-sourcing
if [ -n "${LIB_ERRORS_LOADED:-}" ]; then
    return 0
fi
export LIB_ERRORS_LOADED=1

# Source core library if not already sourced
# Check if colors are defined (indicates lib-core.sh has been sourced)
if [ -z "${RED:-}" ] || [ -z "${GREEN:-}" ] || [ -z "${YELLOW:-}" ] || [ -z "${NC:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# ============================================================================
# Error handling and reporting
# ============================================================================

# Note: Temporary file tracking arrays removed - now handled by lib-temp.sh

# Error reporting function with context and actionable guidance
# 
# Purpose: Reports errors with context and suggests solutions
# 
# Parameters:
#   $1 - Error message (required)
#   $2 - Exit code (optional, default: 1)
# 
# Returns: Exit code (for use with ||)
# 
# Side effects: Prints error message to stderr
# 
# Example:
#   err "Failed to create symlink" 1 || return 1
#   err "File not found: $file. Run with --verbose for details." 2
# 
# Error message format: "Error [script] (timestamp): message"
# Include actionable guidance in the message (e.g., "Try: command --help")
err() {
    local message="$1"
    local exit_code="${2:-1}"
    local script_name="${0##*/}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}Error [$script_name] ($timestamp): $message${NC}" >&2
    return "$exit_code"
}

# Fatal error function that shows line number and exits
# 
# Purpose: Reports fatal errors with line number, call stack, and exits the script
# 
# Parameters:
#   $1 - Error message (required, should include actionable guidance)
#   $2 - Exit code (optional, default: 1)
# 
# Returns: Never returns (exits script)
# 
# Side effects: Prints error message to stderr and exits script
# 
# Example:
#   die "Failed to create directory: $dir. Check permissions and try again." 1
#   die "Required command 'stow' not found. Install with: brew install stow" 1
# 
# Error message format: "Fatal Error [script:line] (timestamp): message [Call stack: ...]"
# Always include actionable guidance in fatal error messages
die() {
    local message="$1"
    local exit_code="${2:-1}"
    local script_name="${0##*/}"
    local line_number
    
    # Get line number with better context
    if is_zsh; then
        # Zsh: use $LINENO or funcfiletrace
        line_number="${LINENO:-?}"
    else
        # Bash: use BASH_LINENO array
        if [ -n "${BASH_LINENO[0]:-}" ]; then
            line_number="${BASH_LINENO[0]}"
        else
            line_number="${LINENO:-?}"
        fi
    fi
    
    # Use get_timestamp if available (from lib-shell.sh), otherwise fallback to date
    local timestamp
    if command -v get_timestamp &> /dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    local call_stack
    call_stack=$(get_call_stack)
    
    local full_message="Fatal Error [$script_name:$line_number] ($timestamp): $message"
    if [ -n "$call_stack" ]; then
        full_message="${full_message} [Call stack: $call_stack]"
    fi
    
    echo -e "${RED}${full_message}${NC}" >&2
    exit "$exit_code"
}

# Warning function
# Usage: warn <message>
# Example: warn "Package already installed"
warn() {
    local message="$1"
    local script_name="${0##*/}"
    # Use get_timestamp if available (from lib-shell.sh), otherwise fallback to date
    local timestamp
    if command -v get_timestamp &> /dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    echo -e "${YELLOW}Warning [$script_name] ($timestamp): $message${NC}" >&2
}

# Info function
# Usage: info <message>
# Example: info "Starting installation"
info() {
    local message="$1"
    local script_name="${0##*/}"
    # Use get_timestamp if available (from lib-shell.sh), otherwise fallback to date
    local timestamp
    if command -v get_timestamp &> /dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    fi
    echo -e "${GREEN}Info [$script_name] ($timestamp): $message${NC}"
}

# Handle signals (INT, TERM)
# Usage: handle_signal <signal>
handle_signal() {
    local signal="$1"
    local script_name="${0##*/}"
    warn "Received $signal signal, cleaning up..."
    cleanup_temp_dir
    exit 130  # Standard exit code for SIGINT
}

# Get function call stack for error reporting
# 
# Purpose: Builds a human-readable function call stack for error context
# 
# Parameters: None
# 
# Returns: Call stack string via echo
# 
# Side effects: None
# 
# Example:
#   stack=$(get_call_stack)
#   echo "Call stack: $stack"
get_call_stack() {
    local stack=""
    
    if is_zsh; then
        # Zsh uses funcfiletrace array
        if [ -n "${funcfiletrace[@]:-}" ]; then
            local i
            for i in "${funcfiletrace[@]}"; do
                if [ -n "$stack" ]; then
                    stack="${stack} -> "
                fi
                stack="${stack}${i}"
            done
        fi
    else
        # Bash uses FUNCNAME and BASH_SOURCE arrays
        if [ -n "${FUNCNAME[@]:-}" ] && [ ${#FUNCNAME[@]} -gt 1 ]; then
            local i
            # Skip first element (current function) and last (main)
            for ((i=1; i<${#FUNCNAME[@]}-1; i++)); do
                if [ -n "$stack" ]; then
                    stack="${stack} -> "
                fi
                local func="${FUNCNAME[$i]}"
                local file="${BASH_SOURCE[$i]##*/}"
                local line="${BASH_LINENO[$i-1]}"
                stack="${stack}${func}(${file}:${line})"
            done
        fi
    fi
    
    echo -n "$stack"
}

# Handle errors with enhanced context
# Usage: handle_error <exit_code> <line_number>
# 
# Purpose: Enhanced error handler that includes call stack information
handle_error() {
    local exit_code="$1"
    local line_number="$2"
    local script_name="${0##*/}"
    local call_stack
    call_stack=$(get_call_stack)
    
    local error_msg="Error at line $line_number (exit code: $exit_code)"
    if [ -n "$call_stack" ]; then
        error_msg="${error_msg} [Call stack: $call_stack]"
    fi
    
    # Use log_error if available, otherwise use err
    if command -v log_error &> /dev/null; then
        log_error "$error_msg"
    else
        err "$error_msg" "$exit_code"
    fi
    cleanup_temp_dir
}

# Function cleanup handler (for RETURN trap)
# Usage: Internal use by setup_function_traps
# 
# Purpose: Handles cleanup when a function returns
_function_return_handler() {
    local exit_code=$?
    # Only perform cleanup if function exited with error
    if [ $exit_code -ne 0 ]; then
        # Could add function-specific cleanup here if needed
        :
    fi
    return $exit_code
}

# Setup function-level traps (RETURN trap)
# Usage: setup_function_traps [cleanup_function]
# 
# Purpose: Sets up RETURN trap for function-level cleanup and error tracking
#   This allows tracking when functions return and performing cleanup
# 
# Parameters:
#   $1 - Optional cleanup function to call on function return
# 
# Returns: Nothing
# 
# Side effects: Sets up RETURN trap
# 
# Example:
#   setup_function_traps my_cleanup
setup_function_traps() {
    local cleanup_func="${1:-}"
    
    if [ -n "$cleanup_func" ]; then
        # Use provided cleanup function
        trap "$cleanup_func" RETURN
    else
        # Use default handler
        trap '_function_return_handler' RETURN
    fi
}

# Enable debug tracing with BASH_XTRACEFD (Bash 5.1+)
# Usage: enable_debug_tracing [log_file]
# 
# Purpose: Redirects set -x output to a separate file descriptor
#   This allows debug output to be separated from stdout/stderr
# 
# Parameters:
#   $1 - Optional log file path (default: /tmp/debug-$$.log)
# 
# Returns: 0 on success, 1 if not supported
# 
# Side effects: Sets up BASH_XTRACEFD and enables tracing
# 
# Example:
#   enable_debug_tracing "/tmp/my-debug.log"
#   set -x
enable_debug_tracing() {
    local log_file="${1:-/tmp/debug-$$.log}"
    
    if ! has_xtracefd_support; then
        # Not supported, return failure
        return 1
    fi
    
    # Create log file
    touch "$log_file" 2>/dev/null || return 1
    
    # Open file descriptor for debug output
    exec {BASH_XTRACEFD}>"$log_file" || return 1
    
    # Enable tracing
    set -x
    
    return 0
}

# Wait for any background process to complete (Bash 5.1+)
# Usage: wait_for_any_process
# 
# Purpose: Waits for any background process to complete
#   Uses wait -n when available (Bash 5.1+), falls back to wait
# 
# Parameters: None
# 
# Returns: Exit code of the completed process
# 
# Side effects: Waits for a background process
# 
# Example:
#   some_command &
#   wait_for_any_process
wait_for_any_process() {
    if has_wait_n_support; then
        # Bash 5.1+: use wait -n
        wait -n
        return $?
    else
        # Fallback: wait for all background processes
        wait
        return $?
    fi
}

# Setup trap handlers for cleanup and error handling
# Usage: setup_traps [cleanup_function]
# Example: setup_traps cleanup_temp_dir
# 
# Purpose: Sets up comprehensive trap handlers for signals, errors, and cleanup
#   Enhanced with RETURN trap support and better error context
setup_traps() {
    local cleanup_func="${1:-cleanup_temp_dir}"
    
    # Cleanup on exit
    trap "$cleanup_func" EXIT
    
    # Handle signals gracefully
    trap "handle_signal INT" INT
    trap "handle_signal TERM" TERM
    
    # Error handler with enhanced context
    # Use BASH_LINENO for better line number reporting
    if [[ "${-}" != *e* ]]; then
        if is_zsh; then
            trap 'handle_error $? $LINENO' ERR
        else
            # Bash: use BASH_LINENO for more accurate line numbers
            trap 'handle_error $? ${BASH_LINENO[0]:-$LINENO}' ERR
        fi
    fi
    
    # Setup function return trap if supported
    # RETURN trap is available in both Bash and zsh
    setup_function_traps
}

# Note: Temporary file management has been moved to lib-temp.sh
# Source lib-temp.sh if not already sourced
if [ -z "${LIB_TEMP_LOADED:-}" ] && [ -f "$(dirname "$0")/lib-temp.sh" ]; then
    source "$(dirname "$0")/lib-temp.sh"
fi
