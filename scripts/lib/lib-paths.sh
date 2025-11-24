#!/bin/bash
# Path and directory utilities library
# Provides functions for determining dotfiles directory and common path variables
# Requires: lib-os.sh (for detect_os)

# Prevent re-sourcing
if [ -n "${LIB_PATHS_LOADED:-}" ]; then
    return 0
fi
export LIB_PATHS_LOADED=1

# Source OS detection if not already sourced
if ! command -v detect_os &> /dev/null; then
    source "$(dirname "$0")/lib-os.sh"
fi

# ============================================================================
# Path Utilities
# ============================================================================

# Get the root directory of the dotfiles repository
# 
# Purpose: Determines the absolute path to the dotfiles repository root
# 
# Parameters: None
# 
# Returns: Absolute path to dotfiles directory via echo
# 
# Side effects: None
# 
# Example:
#   DOTFILES_DIR=$(get_dotfiles_dir)
#   echo "Dotfiles are in: $DOTFILES_DIR"
# 
# Note: Assumes this file is in dotfiles/scripts/lib/, so it goes up two levels
get_dotfiles_dir() {
    # This file is in dotfiles/scripts/lib/
    # So we go up two levels from lib/ to get dotfiles/
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo -n "$(cd "$script_dir/../.." && pwd)"
}

# ============================================================================
# Common Variables Initialization
# ============================================================================

# Initialize common path variables
# These are set when this library is sourced
DOTFILES_DIR="$(get_dotfiles_dir)"
STOW_DIR="$DOTFILES_DIR/stow"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
OS="$(detect_os)"

