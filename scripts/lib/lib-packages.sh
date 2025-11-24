#!/bin/bash
# Package checking helper functions
# Provides functions for checking Homebrew packages, taps, casks, and IDE extensions
# Requires: lib-core.sh (for common variables)

# Source core library if not already sourced
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# ============================================================================
# Package status caching (associative arrays)
# ============================================================================

# Cache initialization flag
PACKAGE_CACHE_INITIALIZED=false

# Associative arrays for caching (Bash 4+ or zsh)
# For Bash 3.2 compatibility, we'll check and use alternative approach if needed
# Use zsh-specific typeset -A if running under zsh for better performance
if is_zsh; then
    # Zsh uses typeset -A for associative arrays
    typeset -A TAP_CACHE
    typeset -A PACKAGE_CACHE
    typeset -A CASK_CACHE
    typeset -A VSCODE_EXT_CACHE
    typeset -A CURSOR_EXT_CACHE
elif declare -A PACKAGE_CACHE 2>/dev/null; then
    # Bash 4+ uses declare -A
    declare -A TAP_CACHE 2>/dev/null || true
    declare -A CASK_CACHE 2>/dev/null || true
    declare -A VSCODE_EXT_CACHE 2>/dev/null || true
    declare -A CURSOR_EXT_CACHE 2>/dev/null || true
else
    # Bash 3.2 or earlier - associative arrays not supported
    # Cache will be disabled
    PACKAGE_CACHE_INITIALIZED=false
fi

# Check if associative arrays are supported
# Uses zsh typeset -A or Bash declare -A
check_assoc_array_support() {
    if is_zsh; then
        # Zsh always supports associative arrays
        return 0
    fi
    # Test if declare -A works (Bash 4+)
    local test_array
    if declare -A test_array 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Initialize package status cache
# Usage: init_package_cache
# Populates cache with current package status
init_package_cache() {
    if [ "$PACKAGE_CACHE_INITIALIZED" = true ]; then
        return 0  # Already initialized
    fi
    
    if ! check_assoc_array_support; then
        log_debug "Associative arrays not supported, skipping cache initialization"
        PACKAGE_CACHE_INITIALIZED=false
        return 0
    fi
    
    log_debug "Initializing package status cache..."
    
    # Only initialize if brew is available
    if ! command -v brew &> /dev/null; then
        log_debug "Homebrew not found, skipping cache initialization"
        PACKAGE_CACHE_INITIALIZED=true
        return 0
    fi
    
    # Cache all installed packages
    local packages_array
    readarray -t packages_array < <(brew list --formula 2>/dev/null || echo "")
    for pkg in "${packages_array[@]}"; do
        [ -n "$pkg" ] && PACKAGE_CACHE["$pkg"]="installed"
    done
    
    # Cache all installed casks
    local casks_array
    readarray -t casks_array < <(brew list --cask 2>/dev/null || echo "")
    for cask in "${casks_array[@]}"; do
        [ -n "$cask" ] && CASK_CACHE["$cask"]="installed"
    done
    
    # Cache all taps
    local taps_array
    readarray -t taps_array < <(brew tap 2>/dev/null || echo "")
    for tap in "${taps_array[@]}"; do
        [ -n "$tap" ] && TAP_CACHE["$tap"]="installed"
    done
    
    # Cache VS Code extensions
    if command -v code &> /dev/null; then
        local vscode_exts_array
        readarray -t vscode_exts_array < <(code --list-extensions 2>/dev/null || echo "")
        for ext in "${vscode_exts_array[@]}"; do
            [ -n "$ext" ] && VSCODE_EXT_CACHE["$ext"]="installed"
        done
    fi
    
    # Cache Cursor extensions
    local cursor_cmd
    cursor_cmd=$(get_cursor_command)
    if [ -n "$cursor_cmd" ]; then
        local cursor_exts_array
        readarray -t cursor_exts_array < <("$cursor_cmd" --list-extensions 2>/dev/null || echo "")
        for ext in "${cursor_exts_array[@]}"; do
            [ -n "$ext" ] && CURSOR_EXT_CACHE["$ext"]="installed"
        done
    fi
    
    PACKAGE_CACHE_INITIALIZED=true
    log_debug "Package cache initialized"
}

# Get cached package status
# Usage: get_cached_package_status <package_name> <cache_type>
# Returns: "installed" or "missing" via echo
# cache_type: "package", "cask", "tap", "vscode_ext", "cursor_ext"
get_cached_package_status() {
    local name="$1"
    local cache_type="$2"
    
    if [ "$PACKAGE_CACHE_INITIALIZED" != true ]; then
        echo -n "unknown"
        return 0
    fi
    
    # Check if associative arrays are supported
    if ! check_assoc_array_support; then
        echo -n "unknown"
        return 0
    fi
    
    case "$cache_type" in
        "package")
            if [[ -v PACKAGE_CACHE["$name"] ]]; then
                echo -n "${PACKAGE_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "cask")
            if [[ -v CASK_CACHE["$name"] ]]; then
                echo -n "${CASK_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "tap")
            if [[ -v TAP_CACHE["$name"] ]]; then
                echo -n "${TAP_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "vscode_ext")
            if [[ -v VSCODE_EXT_CACHE["$name"] ]]; then
                echo -n "${VSCODE_EXT_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "cursor_ext")
            if [[ -v CURSOR_EXT_CACHE["$name"] ]]; then
                echo -n "${CURSOR_EXT_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        *)
            echo -n "unknown"
            ;;
    esac
}

# Update package cache for a specific item
# Usage: update_package_cache <package_name> <status> <cache_type>
# status: "installed" or "missing"
# cache_type: "package", "cask", "tap", "vscode_ext", "cursor_ext"
update_package_cache() {
    local name="$1"
    local status="$2"
    local cache_type="$3"
    
    if ! check_assoc_array_support; then
        return 0  # Skip if not supported
    fi
    
    case "$cache_type" in
        "package")
            PACKAGE_CACHE["$name"]="$status"
            ;;
        "cask")
            CASK_CACHE["$name"]="$status"
            ;;
        "tap")
            TAP_CACHE["$name"]="$status"
            ;;
        "vscode_ext")
            VSCODE_EXT_CACHE["$name"]="$status"
            ;;
        "cursor_ext")
            CURSOR_EXT_CACHE["$name"]="$status"
            ;;
    esac
}

# Get Cursor command path
# Usage: get_cursor_command
# Returns: cursor command path via echo, or empty string if not found
get_cursor_command() {
    if command -v cursor &> /dev/null; then
        echo "cursor"
    elif [ -f "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]; then
        echo "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    fi
}

# Check if a tap is installed (uses cache if available)
# Usage: is_tap_installed <tap_name>
# Returns: 0 if installed, 1 if not
is_tap_installed() {
    local tap="$1"
    local cached_status
    
    # Try cache first
    if [ "$PACKAGE_CACHE_INITIALIZED" = true ]; then
        cached_status=$(get_cached_package_status "$tap" "tap")
        if [ "$cached_status" = "installed" ]; then
            return 0
        elif [ "$cached_status" = "missing" ]; then
            return 1
        fi
    fi
    
    # Fallback to actual check
    if command -v brew &> /dev/null; then
        if brew tap | grep -q "^$tap"; then
            # Update cache
            update_package_cache "$tap" "installed" "tap"
            return 0
        else
            # Update cache
            update_package_cache "$tap" "missing" "tap"
            return 1
        fi
    fi
    
    return 1
}

# Check if a Homebrew package is installed (uses cache if available)
# Usage: is_brew_package_installed <package_name>
# Returns: 0 if installed, 1 if not
is_brew_package_installed() {
    local pkg="$1"
    local cached_status
    
    # Try cache first
    if [ "$PACKAGE_CACHE_INITIALIZED" = true ]; then
        cached_status=$(get_cached_package_status "$pkg" "package")
        if [ "$cached_status" = "installed" ]; then
            return 0
        elif [ "$cached_status" = "missing" ]; then
            return 1
        fi
    fi
    
    # Fallback to actual check
    if command -v brew &> /dev/null; then
        if brew list "$pkg" &>/dev/null 2>&1; then
            # Update cache
            update_package_cache "$pkg" "installed" "package"
            return 0
        else
            # Update cache
            update_package_cache "$pkg" "missing" "package"
            return 1
        fi
    fi
    
    return 1
}

# Check if a Homebrew cask is installed (uses cache if available)
# Usage: is_brew_cask_installed <cask_name>
# Returns: 0 if installed, 1 if not
is_brew_cask_installed() {
    local cask="$1"
    local cached_status
    
    # Try cache first
    if [ "$PACKAGE_CACHE_INITIALIZED" = true ]; then
        cached_status=$(get_cached_package_status "$cask" "cask")
        if [ "$cached_status" = "installed" ]; then
            return 0
        elif [ "$cached_status" = "missing" ]; then
            return 1
        fi
    fi
    
    # Fallback to actual check
    if command -v brew &> /dev/null; then
        if brew list --cask "$cask" &>/dev/null 2>&1; then
            # Update cache
            update_package_cache "$cask" "installed" "cask"
            return 0
        else
            # Update cache
            update_package_cache "$cask" "missing" "cask"
            return 1
        fi
    fi
    
    return 1
}

# Check if a VS Code extension is installed (uses cache if available)
# Usage: is_vscode_extension_installed <extension_id>
# Returns: 0 if installed, 1 if not
is_vscode_extension_installed() {
    local ext="$1"
    local cached_status
    
    if ! command -v code &> /dev/null; then
        return 1
    fi
    
    # Try cache first
    if [ "$PACKAGE_CACHE_INITIALIZED" = true ]; then
        cached_status=$(get_cached_package_status "$ext" "vscode_ext")
        if [ "$cached_status" = "installed" ]; then
            return 0
        elif [ "$cached_status" = "missing" ]; then
            return 1
        fi
    fi
    
    # Fallback to actual check
    if code --list-extensions 2>/dev/null | grep -q "^${ext}$"; then
        # Update cache
        update_package_cache "$ext" "installed" "vscode_ext"
        return 0
    else
        # Update cache
        update_package_cache "$ext" "missing" "vscode_ext"
        return 1
    fi
}

# Check if a Cursor extension is installed (uses cache if available)
# Usage: is_cursor_extension_installed <extension_id> <cursor_cmd>
# Returns: 0 if installed, 1 if not
is_cursor_extension_installed() {
    local ext="$1"
    local cursor_cmd="$2"
    local cached_status
    
    if [ -z "$cursor_cmd" ]; then
        return 1
    fi
    
    # Try cache first
    if [ "$PACKAGE_CACHE_INITIALIZED" = true ]; then
        cached_status=$(get_cached_package_status "$ext" "cursor_ext")
        if [ "$cached_status" = "installed" ]; then
            return 0
        elif [ "$cached_status" = "missing" ]; then
            return 1
        fi
    fi
    
    # Fallback to actual check
    local installed_exts
    installed_exts=$("$cursor_cmd" --list-extensions 2>/dev/null || echo "")
    if echo "$installed_exts" | grep -q "^${ext}$"; then
        # Update cache
        update_package_cache "$ext" "installed" "cursor_ext"
        return 0
    else
        # Update cache
        update_package_cache "$ext" "missing" "cursor_ext"
        return 1
    fi
}

