#!/usr/bin/env bash
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
# Zsh Module Loading
# ============================================================================

# Load zsh modules for enhanced functionality
# 
# Purpose: Conditionally loads zsh modules that provide built-in functionality
#   for better performance and features. Respects modules already loaded in .zshrc
# 
# Parameters: None
# 
# Returns: 0 on success, 1 if not running under zsh
# 
# Side effects: Loads zsh modules and sets export flags (only if not already set)
# 
# Example:
#   load_zsh_modules
#   if [ -n "${ZSH_FILES_LOADED:-}" ]; then
#       zf_mkdir -p "$dir"
#   fi
# 
# Modules loaded:
#   - zsh/files: Built-in file operations (zf_ln, zf_mkdir, zf_rm, zf_chmod)
#   - zsh/stat: Built-in stat command (zstat)
#   - zsh/datetime: Date/time functions (strftime, etc.)
#   - zsh/parameter: Advanced parameter expansion features
#   - zsh/mapfile: Enhanced mapfile (if available)
# 
# Note: Checks for existing ZSH_*_LOADED flags before loading to respect
#   modules already loaded in .zshrc (prevents conflicts and respects user config)
load_zsh_modules() {
    if ! is_zsh; then
        return 1
    fi
    
    # Load zsh/files module for built-in file operations
    # Check if already loaded (from .zshrc) before attempting to load
    if [ -z "${ZSH_FILES_LOADED:-}" ]; then
        # Use -F flag to load specific functions only
        if zmodload -F zsh/files b:zf_ln b:zf_mkdir b:zf_rm b:zf_chmod 2>/dev/null; then
            export ZSH_FILES_LOADED=1
        else
            # Try loading the entire module if selective loading fails
            if zmodload zsh/files 2>/dev/null; then
                export ZSH_FILES_LOADED=1
            fi
        fi
    fi
    
    # Load zsh/stat module for built-in stat command
    if [ -z "${ZSH_STAT_LOADED:-}" ]; then
        if zmodload zsh/stat 2>/dev/null; then
            export ZSH_STAT_LOADED=1
        fi
    fi
    
    # Load zsh/datetime module for date/time functions
    if [ -z "${ZSH_DATETIME_LOADED:-}" ]; then
        if zmodload zsh/datetime 2>/dev/null; then
            export ZSH_DATETIME_LOADED=1
        fi
    fi
    
    # Load zsh/parameter module for advanced parameter expansion
    if [ -z "${ZSH_PARAMETER_LOADED:-}" ]; then
        if zmodload zsh/parameter 2>/dev/null; then
            export ZSH_PARAMETER_LOADED=1
        fi
    fi
    
    # Try to load zsh/mapfile (may not be available in all zsh versions)
    if [ -z "${ZSH_MAPFILE_LOADED:-}" ]; then
        if zmodload zsh/mapfile 2>/dev/null; then
            export ZSH_MAPFILE_LOADED=1
        fi
    fi
    
    return 0
}

# Auto-load zsh modules when running under zsh
if is_zsh; then
    load_zsh_modules
fi

# ============================================================================
# Modern Shell Features (readarray/mapfile helpers)
# ============================================================================

# Assign array to a variable by name (using nameref when available)
# 
# Purpose: Provides a unified interface for array assignment that uses
#   namerefs when available, falling back to eval for older shells
# 
# Parameters:
#   $1 - Array name (without $)
#   $2 - Array values (passed as "${array[@]}")
# 
# Returns: Nothing (populates array via name reference)
# 
# Side effects: Creates/modifies array variable
# 
# Example:
#   local temp=(a b c)
#   assign_to_array target "${temp[@]}"
#   echo "${target[@]}"  # outputs: a b c
# 
# Note: Uses nameref (Bash 4.3+ / zsh) when available, eval fallback otherwise
assign_to_array() {
    local array_name="$1"
    shift
    local values=("$@")
    
    # Use nameref if available (Bash 4.3+ or zsh)
    if has_nameref_support; then
        if is_zsh; then
            # Zsh uses typeset -n for namerefs
            typeset -n array_ref="$array_name"
            array_ref=("${values[@]}")
        else
            # Bash 4.3+ uses local -n or declare -n
            if is_bash_4_3_plus; then
                local -n array_ref="$array_name"
                array_ref=("${values[@]}")
            else
                # Bash 4.0-4.2: use declare -n at function scope
                declare -n array_ref="$array_name"
                array_ref=("${values[@]}")
            fi
        fi
    else
        # Fallback to eval for Bash 3.2 and earlier
        eval "$array_name=(\"\${values[@]}\")"
    fi
}

# Read lines from a file or command into an array
# 
# Purpose: Efficiently reads lines into an array, with zsh optimizations
#   and nameref support when available
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
# Note: Uses zsh-specific features when available for better performance.
#   Uses nameref (Bash 4.3+) when available, eval fallback for older shells.
read_lines_into_array() {
    local array_name="$1"
    local source="$2"
    local temp_array=()
    
    # Use zsh-specific optimizations if available
    if is_zsh; then
        # Zsh has better array handling
        if [ -f "$source" ]; then
            # Read from file using zsh array assignment with parameter expansion
            # Use (@f) flag to split on newlines, preserving empty lines
            temp_array=("${(@f)$(<"$source")}")
        else
            # Execute command and read output
            temp_array=("${(@f)$(eval "$source" 2>/dev/null)}")
        fi
        # Assign using nameref or direct assignment
        if has_nameref_support; then
            typeset -n array_ref="$array_name"
            array_ref=("${temp_array[@]}")
        else
            eval "${array_name}=(\"\${temp_array[@]}\")"
        fi
        return 0
    fi
    
    # Bash implementation
    # Check if source is a file or a command
    if [ -f "$source" ]; then
        # Read from file
        if has_nameref_support && is_bash_4_3_plus; then
            # Use nameref with readarray (Bash 4.3+)
            local -n array_ref="$array_name"
            readarray -t array_ref < "$source" 2>/dev/null || {
                # Fallback: read manually into temp, then assign
                while IFS= read -r line || [ -n "$line" ]; do
                    temp_array+=("$line")
                done < "$source"
                array_ref=("${temp_array[@]}")
            }
        else
            # Use readarray without nameref (Bash 4.0-4.2) or fallback
            readarray -t "$array_name" < "$source" 2>/dev/null || {
                # Fallback for systems without readarray
                while IFS= read -r line || [ -n "$line" ]; do
                    temp_array+=("$line")
                done < "$source"
                assign_to_array "$array_name" "${temp_array[@]}"
            }
        fi
    else
        # Execute command and read output
        if has_nameref_support && is_bash_4_3_plus; then
            # Use nameref with readarray (Bash 4.3+)
            local -n array_ref="$array_name"
            readarray -t array_ref < <(eval "$source" 2>/dev/null) || {
                # Fallback: read manually into temp, then assign
                while IFS= read -r line || [ -n "$line" ]; do
                    temp_array+=("$line")
                done < <(eval "$source" 2>/dev/null)
                array_ref=("${temp_array[@]}")
            }
        else
            # Use readarray without nameref (Bash 4.0-4.2) or fallback
            readarray -t "$array_name" < <(eval "$source" 2>/dev/null) || {
                # Fallback for systems without readarray
                while IFS= read -r line || [ -n "$line" ]; do
                    temp_array+=("$line")
                done < <(eval "$source" 2>/dev/null)
                assign_to_array "$array_name" "${temp_array[@]}"
            }
        fi
    fi
}

# Read null-delimited lines into an array (for find -print0)
# 
# Purpose: Reads null-delimited output (e.g., from find -print0) into an array
#   Uses nameref when available for better performance and safety
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
# 
# Note: Uses mapfile -d '' (Bash 4.4+) with nameref (Bash 4.3+) when available.
#   Falls back to manual reading for older shells.
read_null_delimited_into_array() {
    local array_name="$1"
    local command="$2"
    local temp_array=()
    
    # Use zsh-specific handling if available
    if is_zsh; then
        # Zsh can read null-delimited input using (0) parameter expansion flag
        # Read into temp array first, then assign
        temp_array=("${(@0)$(eval "$command" 2>/dev/null)}")
        if has_nameref_support; then
            typeset -n array_ref="$array_name"
            array_ref=("${temp_array[@]}")
        else
            eval "${array_name}=(\"\${temp_array[@]}\")"
        fi
        return 0
    fi
    
    # Bash implementation
    # Use mapfile with null delimiter (Bash 4.4+) and nameref (Bash 4.3+)
    if has_mapfile_null_delim && has_nameref_support && is_bash_4_3_plus; then
        # Best case: mapfile -d '' with nameref (Bash 4.4+)
        local -n array_ref="$array_name"
        mapfile -d '' -t array_ref < <(eval "$command" 2>/dev/null) 2>/dev/null || {
            # Fallback: read manually
            while IFS= read -r -d '' line || [ -n "$line" ]; do
                temp_array+=("$line")
            done < <(eval "$command" 2>/dev/null)
            array_ref=("${temp_array[@]}")
        }
    elif has_mapfile_null_delim; then
        # mapfile -d '' without nameref (Bash 4.4, but < 4.3 for nameref)
        mapfile -d '' -t "$array_name" < <(eval "$command" 2>/dev/null) 2>/dev/null || {
            # Fallback: read manually
            while IFS= read -r -d '' line || [ -n "$line" ]; do
                temp_array+=("$line")
            done < <(eval "$command" 2>/dev/null)
            assign_to_array "$array_name" "${temp_array[@]}"
        }
    else
        # Fallback for systems without mapfile -d ''
        while IFS= read -r -d '' line || [ -n "$line" ]; do
            temp_array+=("$line")
        done < <(eval "$command" 2>/dev/null)
        assign_to_array "$array_name" "${temp_array[@]}"
    fi
}

# ============================================================================
# Parameter Expansion Helpers
# ============================================================================

# Split a string into an array by delimiter
# 
# Purpose: Splits a string into an array using a delimiter
#   Uses zsh parameter expansion when available for better performance
# 
# Parameters:
#   $1 - Array name (without $) to store results
#   $2 - String to split
#   $3 - Delimiter (default: ",")
# 
# Returns: Nothing (populates array via name reference)
# 
# Side effects: Creates/modifies array variable
# 
# Example:
#   split_string items "a,b,c" ","
#   echo "${items[@]}"  # outputs: a b c
# 
# Note: Uses zsh ${(s:,:)string} when available, fallback for bash
split_string() {
    local array_name="$1"
    local string="$2"
    local delimiter="${3:-,}"
    local temp_array=()
    
    if is_zsh; then
        # Zsh: use (s:) parameter expansion flag
        # Escape delimiter for zsh pattern matching
        local escaped_delim
        # Check if delimiter is a special character that needs escaping
        # Use case statement for bash 3.2 compatibility
        case "$delimiter" in
            ','|';'|':'|'/'|'\'|'*'|'?'|'['|']'|'('|')'|'{'|'}'|'^'|'$'|'|'|'&'|'~'|'#'|'%'|'!'|'@')
                escaped_delim="\\${delimiter}"
                ;;
            *)
                escaped_delim="$delimiter"
                ;;
        esac
        temp_array=("${(@s:${escaped_delim}:)string}")
    else
        # Bash: use IFS and read
        local old_ifs="$IFS"
        IFS="$delimiter"
        read -ra temp_array <<< "$string"
        IFS="$old_ifs"
    fi
    
    # Assign to target array
    if has_nameref_support; then
        if is_zsh; then
            typeset -n array_ref="$array_name"
            array_ref=("${temp_array[@]}")
        else
            local -n array_ref="$array_name"
            array_ref=("${temp_array[@]}")
        fi
    else
        eval "$array_name=(\"\${temp_array[@]}\")"
    fi
}

# Join array elements into a string with delimiter
# 
# Purpose: Joins array elements into a single string with a delimiter
#   Uses zsh parameter expansion when available for better performance
# 
# Parameters:
#   $1 - Array name (without $) or array values
#   $2 - Delimiter (default: ",")
#   $3 - If provided, treat $1 as array name; otherwise treat as values
# 
# Returns: Joined string via echo
# 
# Side effects: None
# 
# Example:
#   items=(a b c)
#   result=$(join_array items ",")
#   echo "$result"  # outputs: a,b,c
# 
# Note: Uses zsh ${(j:,:)array} when available, fallback for bash
join_array() {
    local array_input="$1"
    local delimiter="${2:-,}"
    local is_array_name="${3:-}"
    local array_values=()
    
    if [ -n "$is_array_name" ]; then
        # $1 is array name, need to get values
        if has_nameref_support; then
            if is_zsh; then
                typeset -n array_ref="$array_input"
                array_values=("${array_ref[@]}")
            else
                local -n array_ref="$array_input"
                array_values=("${array_ref[@]}")
            fi
        else
            eval "array_values=(\"\${${array_input}[@]}\")"
        fi
    else
        # Treat remaining args as array values
        shift
        delimiter="${1:-,}"
        shift
        array_values=("$@")
    fi
    
    if is_zsh; then
        # Zsh: use (j:) parameter expansion flag
        # Escape delimiter for zsh pattern
        local escaped_delim
        # Check if delimiter is a special character that needs escaping
        # Use case statement for bash 3.2 compatibility
        case "$delimiter" in
            ','|';'|':'|'/'|'\'|'*'|'?'|'['|']'|'('|')'|'{'|'}'|'^'|'$'|'|'|'&'|'~'|'#'|'%'|'!'|'@')
                escaped_delim="\\${delimiter}"
                ;;
            *)
                escaped_delim="$delimiter"
                ;;
        esac
        echo -n "${(j:${escaped_delim}:)array_values}"
    else
        # Bash: use printf or manual joining
        local first=true
        local result=""
        for item in "${array_values[@]}"; do
            if [ "$first" = true ]; then
                result="$item"
                first=false
            else
                result="${result}${delimiter}${item}"
            fi
        done
        echo -n "$result"
    fi
}

# Convert string to uppercase
# 
# Purpose: Converts a string to uppercase
#   Uses zsh parameter expansion when available (zsh 5.1+)
# 
# Parameters:
#   $1 - String to convert
# 
# Returns: Uppercase string via echo
# 
# Side effects: None
# 
# Example:
#   result=$(uppercase_string "hello")
#   echo "$result"  # outputs: HELLO
# 
# Note: Uses zsh ${string:u} (zsh 5.1+) when available, tr fallback otherwise
uppercase_string() {
    local string="$1"
    
    if is_zsh; then
        # Check zsh version for :u flag (requires zsh 5.1+)
        if [[ "${ZSH_VERSION%%.*}" -ge 5 ]] && [[ "${ZSH_VERSION#*.}" =~ ^[1-9] ]]; then
            # Use zsh parameter expansion
            echo -n "${string:u}"
            return 0
        fi
    fi
    
    # Fallback: use tr
    echo -n "$string" | tr '[:lower:]' '[:upper:]'
}

# Convert string to lowercase
# 
# Purpose: Converts a string to lowercase
#   Uses zsh parameter expansion when available (zsh 5.1+)
# 
# Parameters:
#   $1 - String to convert
# 
# Returns: Lowercase string via echo
# 
# Side effects: None
# 
# Example:
#   result=$(lowercase_string "HELLO")
#   echo "$result"  # outputs: hello
# 
# Note: Uses zsh ${string:l} (zsh 5.1+) when available, tr fallback otherwise
lowercase_string() {
    local string="$1"
    
    if is_zsh; then
        # Check zsh version for :l flag (requires zsh 5.1+)
        if [[ "${ZSH_VERSION%%.*}" -ge 5 ]] && [[ "${ZSH_VERSION#*.}" =~ ^[1-9] ]]; then
            # Use zsh parameter expansion
            echo -n "${string:l}"
            return 0
        fi
    fi
    
    # Fallback: use tr
    echo -n "$string" | tr '[:upper:]' '[:lower:]'
}

# ============================================================================
# Date/Time Helpers
# ============================================================================

# Get formatted timestamp
# 
# Purpose: Returns a formatted timestamp using zsh strftime when available,
#   falling back to external date command
# 
# Parameters:
#   $1 - Format string (optional, default: '%Y-%m-%d %H:%M:%S')
# 
# Returns: Formatted timestamp via echo
# 
# Side effects: None
# 
# Example:
#   timestamp=$(get_timestamp)
#   timestamp=$(get_timestamp '%Y-%m-%d')
# 
# Note: Uses zsh strftime (zsh/datetime) when ZSH_DATETIME_LOADED is set,
#   falls back to external date command otherwise
get_timestamp() {
    local format="${1:-%Y-%m-%d %H:%M:%S}"
    
    # Use zsh strftime if datetime module is loaded
    if is_zsh && [ -n "${ZSH_DATETIME_LOADED:-}" ]; then
        # zsh strftime(format, epoch_time) - use EPOCHSECONDS for current time
        # EPOCHSECONDS is available when zsh/datetime is loaded
        if [ -n "${EPOCHSECONDS:-}" ]; then
            strftime "$format" "$EPOCHSECONDS" 2>/dev/null || {
                # Fallback if strftime fails
                date "+$format" 2>/dev/null || echo ""
            }
        else
            # Fallback if EPOCHSECONDS not available
            date "+$format" 2>/dev/null || echo ""
        fi
    else
        # Fallback to external date command
        date "+$format" 2>/dev/null || echo ""
    fi
}

# Get epoch timestamp (seconds since 1970-01-01)
# 
# Purpose: Returns epoch timestamp using zsh datetime when available,
#   falling back to external date command
# 
# Parameters: None
# 
# Returns: Epoch timestamp (integer) via echo
# 
# Side effects: None
# 
# Example:
#   epoch=$(get_epoch_timestamp)
# 
# Note: Uses zsh EPOCHSECONDS when ZSH_DATETIME_LOADED is set,
#   falls back to external date +%s otherwise
get_epoch_timestamp() {
    # Use zsh EPOCHSECONDS if datetime module is loaded
    if is_zsh && [ -n "${ZSH_DATETIME_LOADED:-}" ]; then
        echo -n "${EPOCHSECONDS:-$(date +%s 2>/dev/null || echo 0)}"
    else
        # Fallback to external date command
        date +%s 2>/dev/null || echo "0"
    fi
}

