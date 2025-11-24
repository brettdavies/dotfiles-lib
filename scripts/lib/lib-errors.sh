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
# Purpose: Reports fatal errors with line number and exits the script
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
# Error message format: "Fatal Error [script:line] (timestamp): message"
# Always include actionable guidance in fatal error messages
die() {
    local message="$1"
    local exit_code="${2:-1}"
    local script_name="${0##*/}"
    local line_number="${BASH_LINENO[0]}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}Fatal Error [$script_name:$line_number] ($timestamp): $message${NC}" >&2
    exit "$exit_code"
}

# Warning function
# Usage: warn <message>
# Example: warn "Package already installed"
warn() {
    local message="$1"
    local script_name="${0##*/}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}Warning [$script_name] ($timestamp): $message${NC}" >&2
}

# Info function
# Usage: info <message>
# Example: info "Starting installation"
info() {
    local message="$1"
    local script_name="${0##*/}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
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

# Handle errors with context
# Usage: handle_error <exit_code> <line_number>
handle_error() {
    local exit_code="$1"
    local line_number="$2"
    local script_name="${0##*/}"
    # Use log_error if available, otherwise use err
    if command -v log_error &> /dev/null; then
        log_error "Error at line $line_number (exit code: $exit_code)"
    else
        err "Error at line $line_number (exit code: $exit_code)" "$exit_code"
    fi
    cleanup_temp_dir
}

# Setup trap handlers for cleanup and error handling
# Usage: setup_traps [cleanup_function]
# Example: setup_traps cleanup_temp_dir
setup_traps() {
    local cleanup_func="${1:-cleanup_temp_dir}"
    
    # Cleanup on exit
    trap "$cleanup_func" EXIT
    
    # Handle signals gracefully
    trap "handle_signal INT" INT
    trap "handle_signal TERM" TERM
    
    # Error handler (only if set -e is not used, or for better error reporting)
    if [[ "${-}" != *e* ]]; then
        trap 'handle_error $? $LINENO' ERR
    fi
}

# Note: Temporary file management has been moved to lib-temp.sh
# Source lib-temp.sh if not already sourced
if [ -z "${LIB_TEMP_LOADED:-}" ] && [ -f "$(dirname "$0")/lib-temp.sh" ]; then
    source "$(dirname "$0")/lib-temp.sh"
fi
