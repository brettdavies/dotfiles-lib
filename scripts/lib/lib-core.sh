#!/usr/bin/env bash
# Core library for dotfiles installation scripts
# Orchestrates loading of all core libraries in the correct order
# This file should be sourced by all scripts
# 
# Note: This file is now a thin orchestrator that sources specialized libraries:
# - lib-constants.sh: Colors and permission constants
# - lib-os.sh: OS and shell detection
# - lib-paths.sh: Path utilities and common variables
# - lib-args.sh: Argument parsing
# - lib-verbose.sh: Verbose output helpers
# - lib-shell.sh: Modern shell features
# - Plus error handling, logging, and other feature libraries

# Prevent re-sourcing
if [ -n "${LIB_CORE_LOADED:-}" ]; then
    return 0
fi
export LIB_CORE_LOADED=1

# Get the directory where this script is located
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# Load core libraries in dependency order
# ============================================================================

# 1. Constants (no dependencies)
source "$_LIB_DIR/lib-constants.sh"

# 2. OS detection (depends on constants)
source "$_LIB_DIR/lib-os.sh"

# Initialize feature flags after OS detection
# These flags indicate which features are available based on shell version
if ! is_zsh; then
    # Bash feature flags
    export BASH_5_2_PLUS=false
    export BASH_5_1_PLUS=false
    export BASH_5_0_PLUS=false
    export BASH_4_4_PLUS=false
    export BASH_4_3_PLUS=false
    export BASH_4_PLUS=false
    
    if is_bash_5_2_plus; then
        export BASH_5_2_PLUS=true
        export BASH_5_1_PLUS=true
        export BASH_5_0_PLUS=true
        export BASH_4_4_PLUS=true
        export BASH_4_3_PLUS=true
        export BASH_4_PLUS=true
    elif is_bash_5_1_plus; then
        export BASH_5_1_PLUS=true
        export BASH_5_0_PLUS=true
        export BASH_4_4_PLUS=true
        export BASH_4_3_PLUS=true
        export BASH_4_PLUS=true
    elif is_bash_5_0_plus; then
        export BASH_5_0_PLUS=true
        export BASH_4_4_PLUS=true
        export BASH_4_3_PLUS=true
        export BASH_4_PLUS=true
    elif is_bash_4_4_plus; then
        export BASH_4_4_PLUS=true
        export BASH_4_3_PLUS=true
        export BASH_4_PLUS=true
    elif is_bash_4_3_plus; then
        export BASH_4_3_PLUS=true
        export BASH_4_PLUS=true
    elif is_bash_4_plus; then
        export BASH_4_PLUS=true
    fi
fi

# 3. Path utilities (depends on OS detection)
source "$_LIB_DIR/lib-paths.sh"

# 4. Argument parsing (depends on constants)
source "$_LIB_DIR/lib-args.sh"

# 5. Verbose output helpers (depends on constants and args)
source "$_LIB_DIR/lib-verbose.sh"

# 6. Modern shell features (depends on OS detection)
source "$_LIB_DIR/lib-shell.sh"

# ============================================================================
# Load feature libraries (error handling, logging, etc.)
# These are automatically loaded when lib-core.sh is sourced
# ============================================================================

# Source error handling (must come after colors are defined)
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_ERRORS_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-errors.sh" ]; then
    source "$_LIB_DIR/lib-errors.sh"
fi

# Source logging (must come after VERBOSE is available from parse_common_args)
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_LOGGING_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-logging.sh" ]; then
    source "$_LIB_DIR/lib-logging.sh"
fi

# Source file operations (before lib-temp.sh for safe_* wrapper functions)
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_FILE_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-file.sh" ]; then
    source "$_LIB_DIR/lib-file.sh"
fi

# Source temporary file management (after lib-errors.sh for err function, after lib-file.sh for safe_* functions)
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_TEMP_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-temp.sh" ]; then
    source "$_LIB_DIR/lib-temp.sh"
fi

# Source filesystem operations
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_FILESYSTEM_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-filesystem.sh" ]; then
    source "$_LIB_DIR/lib-filesystem.sh"
fi

# Source progress indicators (after VERBOSE is available)
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_PROGRESS_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-progress.sh" ]; then
    source "$_LIB_DIR/lib-progress.sh"
fi

# Source validation functions
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_VALIDATION_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-validation.sh" ]; then
    source "$_LIB_DIR/lib-validation.sh"
fi

# Source rollback functionality (after lib-temp.sh for create_temp_file)
# Check if already loaded to prevent re-sourcing
if [ -z "${LIB_ROLLBACK_LOADED:-}" ] && [ -f "$_LIB_DIR/lib-rollback.sh" ]; then
    source "$_LIB_DIR/lib-rollback.sh"
fi

# Clean up internal variable
unset _LIB_DIR
