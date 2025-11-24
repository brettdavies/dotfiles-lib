#!/usr/bin/env bash
# File system operations and optimizations
# Provides optimized find operations, directory caching, and file system utilities
# Requires: lib-core.sh (for DOTFILES_DIR, STOW_DIR)

# Source core library if not already sourced
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# Prevent re-sourcing
if [ -n "${LIB_FILESYSTEM_LOADED:-}" ]; then
    return 0
fi
export LIB_FILESYSTEM_LOADED=1

# Directory listing cache (associative array)
# Key: directory path, Value: newline-separated list of files
# Note: On Bash 3.2 (macOS default), caching is disabled
DIR_CACHE_SUPPORTED=false
declare -A DIR_CACHE 2>/dev/null && DIR_CACHE_SUPPORTED=true || DIR_CACHE_SUPPORTED=false
DIR_CACHE_INITIALIZED=false

# Initialize directory cache
# Usage: init_dir_cache
init_dir_cache() {
    if [ "$DIR_CACHE_INITIALIZED" = true ]; then
        return 0
    fi
    
    # Check if associative arrays are supported (Bash 4+)
    if [ "$DIR_CACHE_SUPPORTED" = false ]; then
        # Bash 3.2 or older - skip caching
        DIR_CACHE_INITIALIZED=true
        return 0
    fi
    
    DIR_CACHE_INITIALIZED=true
}

# Find files using zsh glob qualifiers (zsh only)
# 
# Purpose: Uses zsh glob qualifiers for fast file finding
#   This is significantly faster than find for large directory trees
# 
# Parameters:
#   $1 - Directory to search
#   $2 - File type: "f" for files, "d" for directories, "a" for all, or find-style options
#   $3 - Pattern (optional, e.g., "*.sh")
# 
# Returns: Array of file paths via global variable FIND_RESULTS
# 
# Side effects: Sets FIND_RESULTS array
# 
# Example:
#   find_files_zsh_glob "$dir" "f" "*.sh"
#   echo "${FIND_RESULTS[@]}"
# 
# Note: Only works under zsh. Falls back to find for bash.
#   Glob qualifiers used:
#     (.) = regular files
#     (/) = directories
#     (@) = symlinks
#     (N) = null glob (don't error if no matches)
#     (Om) = sort by modification time (newest first)
#     (On) = sort by name
find_files_zsh_glob() {
    local dir="$1"
    local file_type="${2:-f}"  # f=files, d=directories, a=all
    local pattern="${3:-}"
    
    if ! is_zsh; then
        # Not zsh, return empty (caller should use find fallback)
        FIND_RESULTS=()
        return 1
    fi
    
    # Directory doesn't exist
    if [ ! -d "$dir" ]; then
        FIND_RESULTS=()
        return 0
    fi
    
    # Enable extended_glob locally for this function
    local old_extended_glob
    if [[ -o extended_glob ]]; then
        old_extended_glob=1
    else
        setopt extended_glob
        old_extended_glob=0
    fi
    
    # Build glob pattern
    local glob_pattern
    if [ -n "$pattern" ]; then
        glob_pattern="${dir}/**/${pattern}"
    else
        glob_pattern="${dir}/**/*"
    fi
    
    # Add qualifiers based on file type
    case "$file_type" in
        f|file)
            # Regular files only
            glob_pattern="${glob_pattern}(.)"
            ;;
        d|dir|directory)
            # Directories only
            glob_pattern="${glob_pattern}(/)"
            ;;
        a|all)
            # All files and directories (no qualifier)
            ;;
        *)
            # Try to parse find-style options (basic support)
            if [[ "$file_type" == *"-type f"* ]]; then
                glob_pattern="${glob_pattern}(.)"
            elif [[ "$file_type" == *"-type d"* ]]; then
                glob_pattern="${glob_pattern}(/)"
            fi
            ;;
    esac
    
    # Add null glob qualifier to avoid errors if no matches
    glob_pattern="${glob_pattern}(N)"
    
    # Execute glob and store results
    FIND_RESULTS=($~glob_pattern)
    
    # Restore extended_glob setting
    if [ "$old_extended_glob" -eq 0 ]; then
        unsetopt extended_glob
    fi
    
    return 0
}

# Get directory listing using zsh globs (zsh only)
# 
# Purpose: Uses zsh glob qualifiers for fast directory listing
# 
# Parameters:
#   $1 - Directory to list
#   $2 - File type: "f" for files, "d" for directories, "a" for all
# 
# Returns: Array of paths via global variable DIR_LISTING
# 
# Side effects: Sets DIR_LISTING array
# 
# Example:
#   get_dir_listing_zsh "$dir" "f"
#   echo "${DIR_LISTING[@]}"
# 
# Note: Only works under zsh. Falls back to get_dir_listing() for bash.
get_dir_listing_zsh() {
    local dir="$1"
    local file_type="${2:-a}"
    
    if ! is_zsh; then
        DIR_LISTING=()
        return 1
    fi
    
    # Enable extended_glob locally
    local old_extended_glob
    if [[ -o extended_glob ]]; then
        old_extended_glob=1
    else
        setopt extended_glob
        old_extended_glob=0
    fi
    
    # Build glob pattern based on file type
    local glob_pattern
    case "$file_type" in
        f|file)
            glob_pattern="${dir}/*(.)"  # Regular files only
            ;;
        d|dir|directory)
            glob_pattern="${dir}/*(/)"  # Directories only
            ;;
        a|all)
            glob_pattern="${dir}/*"     # All
            ;;
        *)
            DIR_LISTING=()
            if [ "$old_extended_glob" -eq 0 ]; then
                unsetopt extended_glob
            fi
            return 1
            ;;
    esac
    
    # Add null glob to avoid errors
    glob_pattern="${glob_pattern}(N)"
    
    # Execute glob
    DIR_LISTING=($~glob_pattern)
    
    # Restore extended_glob setting
    if [ "$old_extended_glob" -eq 0 ]; then
        unsetopt extended_glob
    fi
    
    return 0
}

# Find files in a directory and cache the results
# Usage: find_files_in_dir <directory> [find_options]
# Example: find_files_in_dir "$STOW_DIR/git" "-type f -name '*.sh'"
# Returns: array of file paths via global variable FIND_RESULTS
# Also caches results for subsequent calls
find_files_in_dir() {
    local dir="$1"
    local find_opts="${2:--type f}"
    
    # Initialize cache if needed
    init_dir_cache
    
    # Create cache key
    local cache_key="${dir}|||${find_opts}"
    
    # Check cache first (only if supported)
    if [ "$DIR_CACHE_SUPPORTED" = true ] && [ -n "${DIR_CACHE[$cache_key]:-}" ]; then
        # Return cached results
        readarray -t FIND_RESULTS < <(printf '%s\n' "${DIR_CACHE[$cache_key]}") 2>/dev/null || {
            # Fallback for systems without readarray
            FIND_RESULTS=()
            while IFS= read -r line; do
                [ -n "$line" ] && FIND_RESULTS+=("$line")
            done < <(printf '%s\n' "${DIR_CACHE[$cache_key]}")
        }
        return 0
    fi
    
    # Directory doesn't exist
    if [ ! -d "$dir" ]; then
        FIND_RESULTS=()
        if [ "$DIR_CACHE_SUPPORTED" = true ]; then
            DIR_CACHE[$cache_key]=""
        fi
        return 0
    fi
    
    # Try zsh glob qualifiers first if running under zsh
    if is_zsh && [ -n "${ZSH_FILES_LOADED:-}" ]; then
        # Parse find_opts to determine file type and pattern
        local file_type="f"
        local pattern=""
        
        # Extract file type from find_opts
        if [[ "$find_opts" == *"-type d"* ]]; then
            file_type="d"
        elif [[ "$find_opts" == *"-type f"* ]]; then
            file_type="f"
        elif [[ -z "$find_opts" ]] || [[ "$find_opts" == *"-type"* ]]; then
            file_type="a"
        fi
        
        # Extract pattern from find_opts (basic support for -name)
        if [[ "$find_opts" =~ -name[[:space:]]+['"]?([^'"]+)['"]? ]]; then
            pattern="${BASH_REMATCH[1]}"
        fi
        
        # Try zsh glob approach
        if find_files_zsh_glob "$dir" "$file_type" "$pattern"; then
            local temp_array=("${FIND_RESULTS[@]}")
            
            # Cache results if supported
            if [ "$DIR_CACHE_SUPPORTED" = true ]; then
                if [ ${#temp_array[@]} -gt 0 ]; then
                    DIR_CACHE[$cache_key]=$(printf '%s\n' "${temp_array[@]}")
                else
                    DIR_CACHE[$cache_key]=""
                fi
            fi
            
            return 0
        fi
    fi
    
    # Fallback to find command (bash or zsh without glob support)
    local temp_array=()
    while IFS= read -r -d '' file; do
        temp_array+=("$file")
    done < <(find -P "$dir" $find_opts -print0 2>/dev/null)
    
    FIND_RESULTS=("${temp_array[@]}")
    
    # Cache results (store as newline-separated string) - only if supported
    if [ "$DIR_CACHE_SUPPORTED" = true ]; then
        if [ ${#temp_array[@]} -gt 0 ]; then
            DIR_CACHE[$cache_key]=$(printf '%s\n' "${temp_array[@]}")
        else
            DIR_CACHE[$cache_key]=""
        fi
    fi
    
    return 0
}

# Find files in directory and return as array
# Usage: find_files_array <array_name> <directory> [find_options]
# Example: find_files_array files "$STOW_DIR/git" "-type f"
# 
# Note: Uses nameref (Bash 4.3+ / zsh) when available, eval fallback otherwise
find_files_array() {
    local array_name="$1"
    local dir="$2"
    local find_opts="${3:--type f}"
    
    find_files_in_dir "$dir" "$find_opts"
    
    # Use nameref if available, otherwise use eval
    if has_nameref_support; then
        if is_zsh; then
            typeset -n array_ref="$array_name"
            array_ref=("${FIND_RESULTS[@]}")
        else
            local -n array_ref="$array_name"
            array_ref=("${FIND_RESULTS[@]}")
        fi
    else
        eval "$array_name=(\"\${FIND_RESULTS[@]}\")"
    fi
}

# Find directories in a directory and cache the results
# Usage: find_dirs_in_dir <directory> [find_options]
# Example: find_dirs_in_dir "$STOW_DIR/git" "-maxdepth 2"
# Returns: array of directory paths via global variable FIND_RESULTS
find_dirs_in_dir() {
    local dir="$1"
    local find_opts="${2:--type d}"
    
    find_files_in_dir "$dir" "$find_opts"
}

# Clear directory cache
# Usage: clear_dir_cache [directory]
# If directory is provided, only clears cache for that directory
# Otherwise clears entire cache
clear_dir_cache() {
    if [ "$DIR_CACHE_SUPPORTED" = false ]; then
        return 0  # Caching not supported
    fi
    
    local dir="${1:-}"
    
    if [ -z "$dir" ]; then
        # Clear entire cache
        DIR_CACHE=()
    else
        # Clear cache entries for this directory
        local keys_to_remove=()
        for key in "${!DIR_CACHE[@]}"; do
            if [[ "$key" == "$dir"* ]]; then
                keys_to_remove+=("$key")
            fi
        done
        for key in "${keys_to_remove[@]}"; do
            unset DIR_CACHE[$key]
        done
    fi
}

# Get directory listing (cached)
# Usage: get_dir_listing <directory> [file_type]
# file_type: "f" for files, "d" for directories, "a" for all
# Returns: array of paths via global variable DIR_LISTING
# 
# Note: Uses zsh glob qualifiers when available for better performance
get_dir_listing() {
    local dir="$1"
    local file_type="${2:-a}"  # f=files, d=directories, a=all
    
    # Try zsh glob approach first if available
    if is_zsh && [ -n "${ZSH_FILES_LOADED:-}" ]; then
        if get_dir_listing_zsh "$dir" "$file_type"; then
            return 0
        fi
    fi
    
    # Fallback to find-based approach
    case "$file_type" in
        f)
            find_files_in_dir "$dir" "-type f"
            DIR_LISTING=("${FIND_RESULTS[@]}")
            ;;
        d)
            find_dirs_in_dir "$dir" "-type d"
            DIR_LISTING=("${FIND_RESULTS[@]}")
            ;;
        a)
            find_files_in_dir "$dir" ""
            DIR_LISTING=("${FIND_RESULTS[@]}")
            ;;
        *)
            err "Invalid file_type: $file_type (must be f, d, or a)" 1
            DIR_LISTING=()
            return 1
            ;;
    esac
}

# Check if directory listing is cached
# Usage: is_dir_cached <directory> [find_options]
# Returns: 0 if cached, 1 if not cached
is_dir_cached() {
    if [ "$DIR_CACHE_SUPPORTED" = false ]; then
        return 1  # Not cached (caching not supported)
    fi
    
    local dir="$1"
    local find_opts="${2:--type f}"
    local cache_key="${dir}|||${find_opts}"
    
    [ -n "${DIR_CACHE[$cache_key]:-}" ]
}

# Optimized find operation that uses cache when possible
# Usage: cached_find <directory> <find_options>
# Example: cached_find "$STOW_DIR/git" "-type f -name '*.sh'"
# Returns: array of paths via global variable CACHED_FIND_RESULTS
cached_find() {
    local dir="$1"
    local find_opts="$2"
    
    find_files_in_dir "$dir" "$find_opts"
    CACHED_FIND_RESULTS=("${FIND_RESULTS[@]}")
}

# Count files in directory (cached)
# Usage: count_files_in_dir <directory> [find_options]
# Returns: count via echo
count_files_in_dir() {
    local dir="$1"
    local find_opts="${2:--type f}"
    
    find_files_in_dir "$dir" "$find_opts"
    echo "${#FIND_RESULTS[@]}"
}

# Check if directory is empty (cached)
# Usage: is_dir_empty <directory>
# Returns: 0 if empty, 1 if not empty
is_dir_empty() {
    local dir="$1"
    local count
    count=$(count_files_in_dir "$dir" "")
    [ "$count" -eq 0 ]
}

