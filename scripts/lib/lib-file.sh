#!/usr/bin/env bash
# File operations helper functions
# Provides functions for file operations like getting permissions
# Requires: lib-core.sh (for common variables)

# Source core library if not already sourced
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# Get file permissions in a cross-platform way
# 
# Purpose: Retrieves file permissions as an octal string, working on both macOS and Linux
# 
# Parameters:
#   $1 - File path (required)
# 
# Returns: Permissions as octal string (e.g., "600", "755") via echo
# 
# Side effects: None
# 
# Example:
#   PERMS=$(get_file_permissions ~/.secrets)
#   if [ "$PERMS" = "600" ]; then
#       echo "Permissions are correct"
#   fi
# 
# Note: Uses stat -f on macOS and stat -c on Linux
get_file_permissions() {
    local file="$1"
    stat -f "%OLp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null
}

