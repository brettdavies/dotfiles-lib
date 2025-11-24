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
        DIR_CACHE[$cache_key]=""
        return 0
    fi
    
    # Find files and cache results
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
find_files_array() {
    local array_name="$1"
    local dir="$2"
    local find_opts="${3:--type f}"
    
    find_files_in_dir "$dir" "$find_opts"
    eval "$array_name=(\"\${FIND_RESULTS[@]}\")"
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
get_dir_listing() {
    local dir="$1"
    local file_type="${2:-a}"  # f=files, d=directories, a=all
    
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

