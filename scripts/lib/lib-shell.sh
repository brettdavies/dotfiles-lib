#!/bin/bash
# Modern shell features library
# Provides functions for modern shell features like readarray/mapfile helpers
# Requires: lib-os.sh (for is_zsh)

# Prevent re-sourcing
if [ -n "${LIB_SHELL_LOADED:-}" ]; then
    return 0
fi
export LIB_SHELL_LOADED=1

# Source OS detection if not already sourced
if ! command -v is_zsh &> /dev/null; then
    source "$(dirname "$0")/lib-os.sh"
fi

# ============================================================================
# Modern Shell Features (readarray/mapfile helpers)
# ============================================================================

# Read lines from a file or command into an array
# 
# Purpose: Efficiently reads lines into an array, with zsh optimizations
# 
# Parameters:
#   $1 - Array name (without $)
#   $2 - File path or command to execute
# 
# Returns: Nothing (populates array via name reference)
# 
# Side effects: Creates/modifies array variable
# 
# Example:
#   read_lines_into_array files "find . -type f"
#   echo "${files[@]}"
# 
# Note: Uses zsh-specific features when available for better performance
read_lines_into_array() {
    local array_name="$1"
    local source="$2"
    
    # Use zsh-specific optimizations if available
    if is_zsh; then
        # Zsh has better array handling
        if [ -f "$source" ]; then
            # Read from file using zsh array assignment
            eval "${array_name}=(\"\${(@f)\$(<\"$source\")}\")"
        else
            # Execute command and read output
            eval "${array_name}=(\"\${(@f)\$(eval \"$source\" 2>/dev/null)}\")"
        fi
        return 0
    fi
    
    # Bash implementation
    # Check if source is a file or a command
    if [ -f "$source" ]; then
        # Read from file
        readarray -t "$array_name" < "$source" 2>/dev/null || {
            # Fallback for systems without readarray
            local temp_array=()
            while IFS= read -r line || [ -n "$line" ]; do
                temp_array+=("$line")
            done < "$source"
            eval "$array_name=(\"\${temp_array[@]}\")"
        }
    else
        # Execute command and read output
        readarray -t "$array_name" < <(eval "$source" 2>/dev/null) || {
            # Fallback for systems without readarray
            local temp_array=()
            while IFS= read -r line || [ -n "$line" ]; do
                temp_array+=("$line")
            done < <(eval "$source" 2>/dev/null)
            eval "$array_name=(\"\${temp_array[@]}\")"
        }
    fi
}

# Read null-delimited lines into an array (for find -print0)
# 
# Purpose: Reads null-delimited output (e.g., from find -print0) into an array
# 
# Parameters:
#   $1 - Array name (without $)
#   $2 - Command to execute (should output null-delimited lines)
# 
# Returns: Nothing (populates array via name reference)
# 
# Side effects: Creates/modifies array variable
# 
# Example:
#   read_null_delimited_into_array files "find . -type f -print0"
#   echo "${files[@]}"
read_null_delimited_into_array() {
    local array_name="$1"
    local command="$2"
    
    # Use mapfile with null delimiter (Bash 4.4+)
    if command -v mapfile &> /dev/null; then
        mapfile -d '' -t "$array_name" < <(eval "$command" 2>/dev/null) 2>/dev/null || {
            # Fallback for older Bash
            local temp_array=()
            while IFS= read -r -d '' line || [ -n "$line" ]; do
                temp_array+=("$line")
            done < <(eval "$command" 2>/dev/null)
            eval "$array_name=(\"\${temp_array[@]}\")"
        }
    else
        # Fallback for systems without mapfile
        local temp_array=()
        while IFS= read -r -d '' line || [ -n "$line" ]; do
            temp_array+=("$line")
        done < <(eval "$command" 2>/dev/null)
        eval "$array_name=(\"\${temp_array[@]}\")"
    fi
}

