#!/bin/bash
# Shared library for dotfiles installation scripts
# Provides common functions and variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -n "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux-musl"* ]]; then
        echo -n "linux"
    else
        echo -n "unknown"
    fi
}

# Get the directory where the install script is located
get_dotfiles_dir() {
    # This assumes scripts are in dotfiles/scripts/
    # So we go up one level from scripts/ to get dotfiles/
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo -n "$(cd "$script_dir/.." && pwd)"
}

# Initialize common variables
DOTFILES_DIR="$(get_dotfiles_dir)"
STOW_DIR="$DOTFILES_DIR/stow"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"
OS="$(detect_os)"

# Check if a directory is a symlink pointing to the expected location
# Usage: check_dir_symlink <target_dir> <expected_source>
# Returns: 0 if correctly symlinked, 1 otherwise
check_dir_symlink() {
    local target_dir="$1"
    local expected_source="$2"
    
    if [ -L "$target_dir" ]; then
        local actual_source=$(readlink "$target_dir")
        # Resolve relative symlinks
        if [[ "$actual_source" != /* ]]; then
            local base_dir
            base_dir="$(cd "$(dirname "$target_dir")" && pwd)" || return 1
            actual_source="$base_dir/$actual_source"
        fi
        # Normalize paths
        local actual_dir expected_dir
        actual_dir="$(cd "$(dirname "$actual_source")" && pwd)" || return 1
        expected_dir="$(cd "$(dirname "$expected_source")" && pwd)" || return 1
        actual_source="$actual_dir/$(basename "$actual_source")"
        expected_source="$expected_dir/$(basename "$expected_source")"
        
        if [ "$actual_source" == "$expected_source" ]; then
            return 0  # Directory is correctly symlinked
        else
            return 1  # Directory symlink points to wrong location
        fi
    fi
    return 1  # Not a symlink
}

# Check if any parent directory of a target file is symlinked to the stow directory
# This handles the case where entire directories are symlinked (e.g., ~/.config/git -> stow/git/dot-config/git)
# Usage: is_parent_dir_symlinked <target_file> <package_name>
# Returns: 0 if parent is symlinked, 1 otherwise
# Sets global variable PARENT_SYMLINKED_DIR if found
is_parent_dir_symlinked() {
    local target_file="$1"
    local package="$2"
    local target_dir=$(dirname "$target_file")
    
    PARENT_SYMLINKED_DIR=""
    
    # Walk up the directory tree from target to HOME
    local check_dir="$target_dir"
    while [[ "$check_dir" != "$HOME" ]] && [[ "$check_dir" != "/" ]]; do
        # Check if this directory should be symlinked (exists in stow package)
        local dir_rel_path="${check_dir#$HOME/}"
        local dir_in_stow=$(echo "$dir_rel_path" | sed 's|\.|dot-|g')
        local expected_stow_dir="$STOW_DIR/$package/$dir_in_stow"
        
        # Check if directory exists in stow and if target is symlinked to it
        if [ -d "$expected_stow_dir" ]; then
            if check_dir_symlink "$check_dir" "$expected_stow_dir"; then
                PARENT_SYMLINKED_DIR="$check_dir"
                return 0  # Found a parent directory that's correctly symlinked
            fi
        fi
        
        check_dir=$(dirname "$check_dir")
    done
    
    return 1  # No parent directory is symlinked
}

# Parse common command-line arguments (--dry-run, --verbose)
# Sets global variables DRY_RUN and VERBOSE
# Usage: parse_common_args "$@"
parse_common_args() {
    DRY_RUN=false
    VERBOSE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            *)
                # Unknown argument, ignore (might be from parent script or script-specific)
                shift
                ;;
        esac
    done
}

# Get file permissions in a cross-platform way
# Usage: get_file_permissions <file_path>
# Returns: permissions as octal string (e.g., "600")
get_file_permissions() {
    local file="$1"
    stat -f "%OLp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null
}

# Transform dotfiles path (dot-* -> .*)
# Usage: transform_dotfiles_path <relative_path>
# Returns: transformed path via echo
transform_dotfiles_path() {
    local rel_path="$1"
    echo "$rel_path" | sed 's|dot-|.|g'
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

# Normalize a path (resolve symlinks and make absolute)
# Usage: normalize_path <path>
# Returns: normalized absolute path via echo
normalize_path() {
    local path="$1"
    local base_dir
    local normalized
    
    # If it's a relative path, resolve it
    if [[ "$path" != /* ]]; then
        base_dir="$(cd "$(dirname "$path")" && pwd)" || return 1
        path="$base_dir/$(basename "$path")"
    fi
    
    # Normalize the path
    normalized="$(cd "$(dirname "$path")" && pwd)/$(basename "$path")" || return 1
    echo "$normalized"
}

# Check if a tap is installed
# Usage: is_tap_installed <tap_name>
# Returns: 0 if installed, 1 if not
is_tap_installed() {
    local tap="$1"
    command -v brew &> /dev/null && brew tap | grep -q "^$tap"
}

# Check if a Homebrew package is installed
# Usage: is_brew_package_installed <package_name>
# Returns: 0 if installed, 1 if not
is_brew_package_installed() {
    local pkg="$1"
    command -v brew &> /dev/null && brew list "$pkg" &>/dev/null 2>&1
}

# Check if a Homebrew cask is installed
# Usage: is_brew_cask_installed <cask_name>
# Returns: 0 if installed, 1 if not
is_brew_cask_installed() {
    local cask="$1"
    command -v brew &> /dev/null && brew list --cask "$cask" &>/dev/null 2>&1
}

# Check if a VS Code extension is installed
# Usage: is_vscode_extension_installed <extension_id>
# Returns: 0 if installed, 1 if not
is_vscode_extension_installed() {
    local ext="$1"
    if ! command -v code &> /dev/null; then
        return 1
    fi
    code --list-extensions 2>/dev/null | grep -q "^${ext}$"
}

# Check if a Cursor extension is installed
# Usage: is_cursor_extension_installed <extension_id> <cursor_cmd>
# Returns: 0 if installed, 1 if not
is_cursor_extension_installed() {
    local ext="$1"
    local cursor_cmd="$2"
    local installed_exts
    installed_exts=$("$cursor_cmd" --list-extensions 2>/dev/null || echo "")
    echo "$installed_exts" | grep -q "^${ext}$"
}

# ============================================================================
# Standardized verbose output helpers
# These functions provide consistent formatting across all scripts
# ============================================================================

# Print verbose "found" status
# Usage: verbose_found <item_name> [additional_info]
# Example: verbose_found "GNU Stow" -> "  → GNU Stow: found"
verbose_found() {
    local item="$1"
    local info="${2:-}"
    if [ "$VERBOSE" = true ]; then
        if [ -n "$info" ]; then
            echo -e "${GREEN}  → $item: found ($info)${NC}"
        else
            echo -e "${GREEN}  → $item: found${NC}"
        fi
    fi
}

# Print verbose "not found (would install)" status
# Usage: verbose_missing <item_name> [additional_info]
# Example: verbose_missing "GNU Stow" -> "  → GNU Stow: not found (would install)"
verbose_missing() {
    local item="$1"
    local info="${2:-would install}"
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}  → $item: not found ($info)${NC}"
    fi
}

# Print verbose "installed" status
# Usage: verbose_installed <item_type> <item_name>
# Example: verbose_installed "Package" "zsh" -> "  → Package: zsh (installed)"
verbose_installed() {
    local type="$1"
    local name="$2"
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}  → $type: $name (installed)${NC}"
    fi
}

# Print verbose "would install" status
# Usage: verbose_would_install <item_type> <item_name>
# Example: verbose_would_install "Package" "zsh" -> "  → Package: zsh (would install)"
verbose_would_install() {
    local type="$1"
    local name="$2"
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}  → $type: $name (would install)${NC}"
    fi
}

# Print verbose "would create" status
# Usage: verbose_would_create <item_path> [target_info]
# Example: verbose_would_create "~/.secrets" -> "  → Would create: ~/.secrets"
verbose_would_create() {
    local item="$1"
    local target="${2:-}"
    if [ "$VERBOSE" = true ]; then
        if [ -n "$target" ]; then
            echo -e "${YELLOW}  → Would create: $item -> $target${NC}"
        else
            echo -e "${YELLOW}  → Would create: $item${NC}"
        fi
    fi
}

# Print verbose "already set up" status
# Usage: verbose_already_setup <item_path> [additional_info]
# Example: verbose_already_setup ".zshrc" -> "    ✓ Already set up: .zshrc"
verbose_already_setup() {
    local item="$1"
    local info="${2:-}"
    if [ "$VERBOSE" = true ]; then
        if [ -n "$info" ]; then
            echo -e "    ${GREEN}✓ Already set up: $item ($info)${NC}"
        else
            echo -e "    ${GREEN}✓ Already set up: $item${NC}"
        fi
    fi
}

# Print verbose conflict warning
# Usage: verbose_conflict <item_path> <reason>
# Example: verbose_conflict ".zshrc" "exists (not a symlink) - would be removed"
verbose_conflict() {
    local item="$1"
    local reason="$2"
    if [ "$VERBOSE" = true ]; then
        echo -e "    ${YELLOW}⚠ Conflict: $item $reason${NC}"
    fi
}

# Print verbose "already exists" status
# Usage: verbose_already_exists <item_path> [additional_info]
# Example: verbose_already_exists ".secrets" "permissions: 600"
verbose_already_exists() {
    local item="$1"
    local info="${2:-}"
    if [ "$VERBOSE" = true ]; then
        if [ -n "$info" ]; then
            echo -e "${GREEN}  → $item already exists ($info)${NC}"
        else
            echo -e "${GREEN}  → $item already exists${NC}"
        fi
    fi
}

# Print verbose "would update" status
# Usage: verbose_would_update <item_path> <change_description>
# Example: verbose_would_update ".secrets" "permissions: 644 -> 600"
verbose_would_update() {
    local item="$1"
    local change="$2"
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}  → Would update: $item ($change)${NC}"
    fi
}

# Print verbose "detected via" status
# Usage: verbose_detected <item_name> <detection_method>
# Example: verbose_detected "LM Studio" "'lms' command"
verbose_detected() {
    local item="$1"
    local method="$2"
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}  → $item detected via $method${NC}"
    fi
}

