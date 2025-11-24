#!/usr/bin/env bash
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
# Check if is_zsh function exists (it should be loaded via lib-core.sh -> lib-os.sh)
if command -v is_zsh >/dev/null 2>&1 && is_zsh; then
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
            # Check if key exists using parameter expansion (works in Bash 4.0+ and zsh)
            # The ${ARRAY[key]+set} pattern returns "set" if key exists, empty otherwise
            if [[ -n "${PACKAGE_CACHE[$name]+set}" ]]; then
                echo -n "${PACKAGE_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "cask")
            if [[ -n "${CASK_CACHE[$name]+set}" ]]; then
                echo -n "${CASK_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "tap")
            if [[ -n "${TAP_CACHE[$name]+set}" ]]; then
                echo -n "${TAP_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "vscode_ext")
            if [[ -n "${VSCODE_EXT_CACHE[$name]+set}" ]]; then
                echo -n "${VSCODE_EXT_CACHE[$name]}"
            else
                echo -n "missing"
            fi
            ;;
        "cursor_ext")
            if [[ -n "${CURSOR_EXT_CACHE[$name]+set}" ]]; then
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

# ============================================================================
# Version comparison and validation functions
# ============================================================================

# Compare version strings (semantic versioning)
# Parameters: $1 - version to check, $2 - version to compare against
# Returns: 0 if version >= compare_version, 1 otherwise
version_ge() {
    local version="$1"
    local compare_version="$2"
    
    # Split versions into arrays
    IFS='.' read -ra version_parts <<< "$version"
    IFS='.' read -ra compare_parts <<< "$compare_version"
    
    # Compare major version
    if [ "${version_parts[0]}" -gt "${compare_parts[0]}" ]; then
        return 0
    elif [ "${version_parts[0]}" -lt "${compare_parts[0]}" ]; then
        return 1
    fi
    
    # Major version equal, check minor
    if [ "${version_parts[1]:-0}" -gt "${compare_parts[1]:-0}" ]; then
        return 0
    elif [ "${version_parts[1]:-0}" -lt "${compare_parts[1]:-0}" ]; then
        return 1
    fi
    
    # Minor version equal, check patch if both have it
    if [ -n "${version_parts[2]:-}" ] && [ -n "${compare_parts[2]:-}" ]; then
        if [ "${version_parts[2]}" -ge "${compare_parts[2]}" ]; then
            return 0
        else
            return 1
        fi
    fi
    
    # If we get here, versions are equal at the compared level
    return 0
}

# Compare version strings (semantic versioning)
# Parameters: $1 - version to check, $2 - version to compare against
# Returns: 0 if version <= compare_version, 1 otherwise
version_le() {
    local version="$1"
    local compare_version="$2"
    
    # Split versions into arrays
    IFS='.' read -ra version_parts <<< "$version"
    IFS='.' read -ra compare_parts <<< "$compare_version"
    
    # Compare major version
    if [ "${version_parts[0]}" -lt "${compare_parts[0]}" ]; then
        return 0
    elif [ "${version_parts[0]}" -gt "${compare_parts[0]}" ]; then
        return 1
    fi
    
    # Major version equal, check minor
    if [ "${version_parts[1]:-0}" -lt "${compare_parts[1]:-0}" ]; then
        return 0
    elif [ "${version_parts[1]:-0}" -gt "${compare_parts[1]:-0}" ]; then
        return 1
    fi
    
    # Minor version equal, check patch if both have it
    if [ -n "${version_parts[2]:-}" ] && [ -n "${compare_parts[2]:-}" ]; then
        if [ "${version_parts[2]}" -le "${compare_parts[2]}" ]; then
            return 0
        else
            return 1
        fi
    fi
    
    # If we get here, versions are equal at the compared level
    return 0
}

# Get installed version of a Homebrew package
# Parameters: $1 - package name
# Returns: version string via echo, or empty string if not found/installed
get_brew_package_version() {
    local pkg="$1"
    
    if ! command -v brew &> /dev/null; then
        echo ""
        return 1
    fi
    
    # Check if package is installed
    if ! brew list "$pkg" &>/dev/null 2>&1; then
        echo ""
        return 1
    fi
    
    # Get version info
    local version_info
    version_info=$(brew info "$pkg" 2>/dev/null | grep -E "^$pkg:" | head -n1)
    
    if [ -z "$version_info" ]; then
        echo ""
        return 1
    fi
    
    # Extract version (format: "package: version")
    if [[ "$version_info" =~ ^[^:]+:[[:space:]]+([0-9]+\.[0-9]+(\.[0-9]+)?(-[^[:space:]]+)?) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    echo ""
    return 1
}

# Get installed version of a Homebrew cask
# Parameters: $1 - cask name
# Returns: version string via echo, or empty string if not found/installed
get_brew_cask_version() {
    local cask="$1"
    
    if ! command -v brew &> /dev/null; then
        echo ""
        return 1
    fi
    
    # Check if cask is installed
    if ! brew list --cask "$cask" &>/dev/null 2>&1; then
        echo ""
        return 1
    fi
    
    # Get version info
    local version_info
    version_info=$(brew info --cask "$cask" 2>/dev/null | grep -E "^$cask:" | head -n1)
    
    if [ -z "$version_info" ]; then
        echo ""
        return 1
    fi
    
    # Extract version (format: "cask: version")
    if [[ "$version_info" =~ ^[^:]+:[[:space:]]+([0-9]+\.[0-9]+(\.[0-9]+)?(-[^[:space:]]+)?) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    echo ""
    return 1
}

# Validate package version against min/max constraints
# Parameters: $1 - installed version, $2 - min_version (optional), $3 - max_version (optional), $4 - max_exclusive (optional, default false)
# Returns: 0 if valid, 1 if invalid
# Note: When max_version comes from caret expansion (e.g., "5.3.0" for "5.2^"), it represents an exclusive upper bound
validate_package_version() {
    local installed_version="$1"
    local min_version="${2:-}"
    local max_version="${3:-}"
    local max_exclusive="${4:-false}"
    
    # If no version constraints, always valid
    if [ -z "$min_version" ] && [ -z "$max_version" ]; then
        return 0
    fi
    
    # If installed version is empty, can't validate (package not installed)
    if [ -z "$installed_version" ]; then
        return 1
    fi
    
    # Check min_version
    if [ -n "$min_version" ]; then
        if ! version_ge "$installed_version" "$min_version"; then
            return 1
        fi
    fi
    
    # Check max_version
    if [ -n "$max_version" ]; then
        if [ "$max_exclusive" = "true" ]; then
            # Use exclusive comparison (<) for caret-expanded max versions
            if ! version_lt "$installed_version" "$max_version"; then
                return 1
            fi
        else
            # Use inclusive comparison (<=) for regular max versions
            if ! version_le "$installed_version" "$max_version"; then
                return 1
            fi
        fi
    fi
    
    return 0
}

# Get version constraints for a package from packages.yaml
# Parameters: $1 - package key, $2 - platform (brew, linux, etc.)
# Sets global variables: PACKAGE_MIN_VERSION, PACKAGE_MAX_VERSION, and PACKAGE_MAX_VERSION_EXCLUSIVE
get_package_version_constraints() {
    local package_key="$1"
    local platform="${2:-}"
    local packages_yaml="${STOW_DIR:-}/brew/packages.yaml"
    
    PACKAGE_MIN_VERSION=""
    PACKAGE_MAX_VERSION=""
    PACKAGE_MAX_VERSION_EXCLUSIVE=false
    
    if [ ! -f "$packages_yaml" ]; then
        return 1
    fi
    
    if ! command -v yq &> /dev/null; then
        return 1
    fi
    
    # Determine if this is a package or cask
    local is_cask=false
    if yq -e ".casks.\"$package_key\"" "$packages_yaml" &>/dev/null; then
        is_cask=true
    fi
    
    local base_path
    if [ "$is_cask" = true ]; then
        base_path=".casks.\"$package_key\""
    else
        base_path=".packages.\"$package_key\""
    fi
    
    # Get target_version first (takes precedence over min/max)
    local target_version=""
    local brew_target_version=""
    
    # Get platform-specific constraints first, then fall back to package-level
    if [ -n "$platform" ] && [ "$platform" = "brew" ]; then
        # Check for brew-specific target_version first
        brew_target_version=$(yq -r "$base_path.brew_target_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        
        # Also check if brew is an object with target_version field
        if [ -z "$brew_target_version" ] || [ "$brew_target_version" = "null" ]; then
            brew_target_version=$(yq -r "$base_path.brew.target_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        fi
        
        # Use brew_target_version if available, otherwise fall back to package-level target_version
        if [ -n "$brew_target_version" ] && [ "$brew_target_version" != "null" ]; then
            target_version="$brew_target_version"
        else
            target_version=$(yq -r "$base_path.target_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        fi
        
        # If target_version is set, expand it and use as min/max (overriding any explicit min/max)
        if [ -n "$target_version" ] && [ "$target_version" != "null" ]; then
            if expand_target_version "$target_version"; then
                PACKAGE_MIN_VERSION="$EXPANDED_MIN_VERSION"
                PACKAGE_MAX_VERSION="$EXPANDED_MAX_VERSION"
                # If target_version had caret, max is exclusive
                if [ "$TARGET_VERSION_HAS_CARET" = true ]; then
                    PACKAGE_MAX_VERSION_EXCLUSIVE=true
                fi
                return 0
            fi
        fi
        
        # No target_version, check for brew-specific min/max constraints
        PACKAGE_MIN_VERSION=$(yq -r "$base_path.brew_min_version // $base_path.min_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        PACKAGE_MAX_VERSION=$(yq -r "$base_path.brew_max_version // $base_path.max_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        
        # Also check if brew is an object with version fields
        if [ -z "$PACKAGE_MIN_VERSION" ] || [ "$PACKAGE_MIN_VERSION" = "null" ]; then
            PACKAGE_MIN_VERSION=$(yq -r "$base_path.brew.min_version // $base_path.min_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        fi
        if [ -z "$PACKAGE_MAX_VERSION" ] || [ "$PACKAGE_MAX_VERSION" = "null" ]; then
            PACKAGE_MAX_VERSION=$(yq -r "$base_path.brew.max_version // $base_path.max_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        fi
    else
        # Use package-level constraints
        target_version=$(yq -r "$base_path.target_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        
        # If target_version is set, expand it and use as min/max
        if [ -n "$target_version" ] && [ "$target_version" != "null" ]; then
            if expand_target_version "$target_version"; then
                PACKAGE_MIN_VERSION="$EXPANDED_MIN_VERSION"
                PACKAGE_MAX_VERSION="$EXPANDED_MAX_VERSION"
                # If target_version had caret, max is exclusive
                if [ "$TARGET_VERSION_HAS_CARET" = true ]; then
                    PACKAGE_MAX_VERSION_EXCLUSIVE=true
                fi
                return 0
            fi
        fi
        
        # No target_version, use package-level min/max
        PACKAGE_MIN_VERSION=$(yq -r "$base_path.min_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
        PACKAGE_MAX_VERSION=$(yq -r "$base_path.max_version // \"\"" "$packages_yaml" 2>/dev/null || echo "")
    fi
    
    # Clean up null values
    if [ "$PACKAGE_MIN_VERSION" = "null" ] || [ -z "$PACKAGE_MIN_VERSION" ]; then
        PACKAGE_MIN_VERSION=""
    fi
    if [ "$PACKAGE_MAX_VERSION" = "null" ] || [ -z "$PACKAGE_MAX_VERSION" ]; then
        PACKAGE_MAX_VERSION=""
    fi
    
    return 0
}

# ============================================================================
# Target version parsing and expansion functions
# ============================================================================

# Parse target_version string to extract base version and check for caret syntax
# Parameters: $1 - target_version string (e.g., "5.2^", "1.6.0")
# Sets global variables: TARGET_VERSION_BASE, TARGET_VERSION_HAS_CARET
parse_target_version() {
    local target_version="$1"
    
    TARGET_VERSION_BASE=""
    TARGET_VERSION_HAS_CARET=false
    
    if [ -z "$target_version" ]; then
        return 1
    fi
    
    # Check if version contains caret
    if [[ "$target_version" =~ \^$ ]]; then
        TARGET_VERSION_HAS_CARET=true
        # Remove caret to get base version
        TARGET_VERSION_BASE="${target_version%^}"
    else
        TARGET_VERSION_BASE="$target_version"
    fi
    
    return 0
}

# Expand target_version with caret syntax to min/max version constraints
# Parameters: $1 - target_version string (e.g., "5.2^")
# Sets global variables: EXPANDED_MIN_VERSION, EXPANDED_MAX_VERSION
# Returns: 0 on success, 1 on failure
expand_target_version() {
    local target_version="$1"
    local base_version
    local has_caret=false
    
    EXPANDED_MIN_VERSION=""
    EXPANDED_MAX_VERSION=""
    
    if [ -z "$target_version" ]; then
        return 1
    fi
    
    # Parse the target version
    if ! parse_target_version "$target_version"; then
        return 1
    fi
    
    base_version="$TARGET_VERSION_BASE"
    has_caret="$TARGET_VERSION_HAS_CARET"
    
    if [ "$has_caret" = true ]; then
        # Expand caret syntax: "X.Y^" means >=X.Y.0, <X.(Y+1).0
        # Split version into parts
        IFS='.' read -ra version_parts <<< "$base_version"
        local major="${version_parts[0]}"
        local minor="${version_parts[1]:-0}"
        
        # Set min version to X.Y.0
        EXPANDED_MIN_VERSION="${major}.${minor}.0"
        
        # Set max version to X.(Y+1).0 (exclusive, so we use < comparison)
        # We'll use a high patch number for the max to represent <X.(Y+1).0
        local next_minor=$((minor + 1))
        EXPANDED_MAX_VERSION="${major}.${next_minor}.0"
    else
        # No caret, treat as exact version (min and max are the same)
        EXPANDED_MIN_VERSION="$base_version"
        EXPANDED_MAX_VERSION="$base_version"
    fi
    
    return 0
}

# Query Homebrew for available versions of a package
# Parameters: $1 - package/cask name, $2 - type ("package" or "cask")
# Returns: list of available versions via echo (one per line), empty on failure
query_brew_versions() {
    local name="$1"
    local type="${2:-package}"
    
    if ! command -v brew &> /dev/null; then
        return 1
    fi
    
    local json_output
    local brew_cmd
    
    if [ "$type" = "cask" ]; then
        brew_cmd="brew info --cask --json=v1"
    else
        brew_cmd="brew info --json=v1"
    fi
    
    # Query Homebrew for package info
    json_output=$($brew_cmd "$name" 2>/dev/null)
    
    if [ -z "$json_output" ]; then
        return 1
    fi
    
    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        # Fallback: try to extract version from brew info text output
        local info_output
        if [ "$type" = "cask" ]; then
            info_output=$(brew info --cask "$name" 2>/dev/null)
        else
            info_output=$(brew info "$name" 2>/dev/null)
        fi
        
        # Extract version from "name: version" line
        if [[ "$info_output" =~ ^[^:]+:[[:space:]]+([0-9]+\.[0-9]+(\.[0-9]+)?(-[^[:space:]]+)?) ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
        return 1
    fi
    
    # Parse JSON to extract versions
    # Homebrew JSON structure: [{"name":"package","versions":{"stable":"1.2.3",...},...}]
    local stable_version
    stable_version=$(echo "$json_output" | jq -r '.[0].versions.stable // empty' 2>/dev/null)
    
    if [ -n "$stable_version" ] && [ "$stable_version" != "null" ]; then
        echo "$stable_version"
        return 0
    fi
    
    # If no stable version, try to get any version field
    local any_version
    any_version=$(echo "$json_output" | jq -r '.[0].versions | to_entries[0].value // empty' 2>/dev/null)
    
    if [ -n "$any_version" ] && [ "$any_version" != "null" ]; then
        echo "$any_version"
        return 0
    fi
    
    return 1
}

# Helper function for version less than comparison
# Parameters: $1 - version to check, $2 - version to compare against
# Returns: 0 if version < compare_version, 1 otherwise
version_lt() {
    local version="$1"
    local compare_version="$2"
    
    # Use version_le and check they're not equal
    if version_le "$version" "$compare_version"; then
        # Check if they're equal
        if version_ge "$version" "$compare_version"; then
            return 1  # Equal, so not less than
        else
            return 0  # Less than
        fi
    else
        return 1  # Greater than or equal
    fi
}

# Find the latest version from a list that matches the constraint
# Parameters: $1 - version list (newline-separated), $2 - min_version, $3 - max_version
# Returns: latest matching version via echo, or empty if none found
find_matching_version() {
    local version_list="$1"
    local min_version="${2:-}"
    local max_version="${3:-}"
    local latest_version=""
    local latest_valid=false
    
    if [ -z "$version_list" ]; then
        return 1
    fi
    
    # If no constraints, return the first (assumed latest) version
    if [ -z "$min_version" ] && [ -z "$max_version" ]; then
        echo "$version_list" | head -n1
        return 0
    fi
    
    # Process each version in the list
    while IFS= read -r version; do
        [ -z "$version" ] && continue
        
        # Clean up version string (remove any trailing whitespace or special chars)
        version=$(echo "$version" | xargs)
        
        # Check if version matches constraints
        local matches=true
        
        if [ -n "$min_version" ]; then
            if ! version_ge "$version" "$min_version"; then
                matches=false
            fi
        fi
        
        if [ "$matches" = true ] && [ -n "$max_version" ]; then
            # For max_version from caret expansion (X.(Y+1).0), we want < comparison
            # So we check if version < max_version
            if ! version_lt "$version" "$max_version"; then
                matches=false
            fi
        fi
        
        if [ "$matches" = true ]; then
            # This version matches, check if it's newer than current latest
            if [ "$latest_valid" = false ]; then
                latest_version="$version"
                latest_valid=true
            elif version_ge "$version" "$latest_version"; then
                latest_version="$version"
            fi
        fi
    done <<< "$version_list"
    
    if [ "$latest_valid" = true ]; then
        echo "$latest_version"
        return 0
    fi
    
    return 1
}

