#!/usr/bin/env bash
# Input validation and sanitization functions
# Provides functions for validating paths, filenames, and arguments
# Requires: lib-core.sh (for DOTFILES_DIR, HOME)

# Prevent re-sourcing
if [ -n "${LIB_VALIDATION_LOADED:-}" ]; then
    return 0
fi
export LIB_VALIDATION_LOADED=1

# Source core library if not already sourced
# Check if DOTFILES_DIR is defined (indicates lib-core.sh has been sourced)
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# Validate that a path is within a given directory
# Usage: validate_path_within <path> <base_dir> [description]
# Returns: 0 if valid, 1 if invalid
# Example: validate_path_within "$HOME/.zshrc" "$HOME" "home path"
validate_path_within() {
    local path="$1"
    local base_dir="$2"
    local description="${3:-path}"
    
    # Normalize paths
    local normalized_path
    normalized_path=$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path") || {
        err "Invalid $description: $path (cannot normalize)"
        return 1
    }
    
    local normalized_base
    normalized_base=$(cd "$base_dir" 2>/dev/null && pwd) || {
        err "Invalid base directory: $base_dir"
        return 1
    }
    
    # Check if path starts with base directory
    if [[ "$normalized_path" != "$normalized_base"/* ]] && [[ "$normalized_path" != "$normalized_base" ]]; then
        err "Invalid $description: $path (outside base directory $base_dir)"
        return 1
    fi
    
    return 0
}

# Validate that a path is within HOME directory
# Usage: validate_home_path <path>
# Returns: 0 if valid, 1 if invalid
# Example: validate_home_path "$HOME/.zshrc"
validate_home_path() {
    validate_path_within "$1" "$HOME" "home path"
}

# Validate that a path is within the dotfiles repository
# Usage: validate_repo_path <path>
# Returns: 0 if valid, 1 if invalid
# Example: validate_repo_path "$DOTFILES_DIR/stow/zsh/dot-zshrc"
validate_repo_path() {
    validate_path_within "$1" "$DOTFILES_DIR" "repository path"
}

# Sanitize a filename to prevent path traversal and other issues
# Usage: sanitize_filename <filename>
# Returns: sanitized filename via echo
# Example: safe_name=$(sanitize_filename "../../etc/passwd")  # Returns "etc_passwd"
sanitize_filename() {
    local filename="$1"
    
    # Remove leading slashes and dots
    filename="${filename#/}"
    filename="${filename#./}"
    filename="${filename#../}"
    
    # Replace path separators and dangerous characters with underscores
    filename="${filename//\//_}"
    filename="${filename//\\/_}"
    filename="${filename//\*/_}"
    filename="${filename//\?/_}"
    filename="${filename//</_}"
    filename="${filename//>/_}"
    filename="${filename//|/_}"
    filename="${filename//\"/_}"
    filename="${filename//:/_}"
    
    # Remove leading/trailing dots and spaces
    filename="${filename#.}"
    filename="${filename%.}"
    filename="${filename#"${filename%%[![:space:]]*}"}"  # Remove leading spaces
    filename="${filename%"${filename##*[![:space:]]}"}"  # Remove trailing spaces
    
    # If empty after sanitization, use a default
    if [ -z "$filename" ]; then
        filename="file"
    fi
    
    echo -n "$filename"
}

# Prevent path traversal attacks
# Usage: prevent_path_traversal <path> <base_dir>
# Returns: 0 if safe, 1 if path traversal detected
# Example: prevent_path_traversal "../../etc/passwd" "$HOME"
prevent_path_traversal() {
    local path="$1"
    local base_dir="$2"
    
    # Check for path traversal patterns
    if [[ "$path" == *".."* ]] || [[ "$path" == *"/.."* ]] || [[ "$path" == *"../"* ]]; then
        err "Path traversal detected: $path"
        return 1
    fi
    
    # Validate path is within base directory
    validate_path_within "$path" "$base_dir" "path"
}

# Validate command-line arguments
# Usage: validate_args <arg1> <arg2> ...
# Returns: 0 if all valid, 1 if any invalid
# Example: validate_args "$package_name" "$target_dir"
validate_args() {
    local arg
    local arg_num=1
    
    for arg in "$@"; do
        # Check for empty arguments (unless explicitly allowed)
        if [ -z "$arg" ]; then
            err "Argument $arg_num is empty"
            return 1
        fi
        
        # Check for null bytes (indicates binary data or injection attempt)
        if [[ "$arg" == *$'\0'* ]]; then
            err "Argument $arg_num contains null bytes (invalid)"
            return 1
        fi
        
        ((arg_num++))
    done
    
    return 0
}

# Validate that a directory exists and is accessible
# Usage: validate_directory <dir_path> [description]
# Returns: 0 if valid, 1 if invalid
# Example: validate_directory "$HOME/.config" "config directory"
validate_directory() {
    local dir_path="$1"
    local description="${2:-directory}"
    
    if [ ! -d "$dir_path" ]; then
        err "$description does not exist: $dir_path"
        return 1
    fi
    
    if [ ! -r "$dir_path" ]; then
        err "$description is not readable: $dir_path"
        return 1
    fi
    
    return 0
}

# Validate that a file exists and is accessible
# Usage: validate_file <file_path> [description]
# Returns: 0 if valid, 1 if invalid
# Example: validate_file "$HOME/.zshrc" "zshrc file"
validate_file() {
    local file_path="$1"
    local description="${2:-file}"
    
    if [ ! -f "$file_path" ]; then
        err "$description does not exist: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        err "$description is not readable: $file_path"
        return 1
    fi
    
    return 0
}

# Validate package name format (for stow packages)
# Usage: validate_package_name <package_name>
# Returns: 0 if valid, 1 if invalid
# Example: validate_package_name "zsh"
validate_package_name() {
    local package_name="$1"
    
    if [ -z "$package_name" ]; then
        err "Package name cannot be empty"
        return 1
    fi
    
    # Check for invalid characters
    if [[ "$package_name" =~ [^a-zA-Z0-9_-] ]]; then
        err "Invalid package name: $package_name (contains invalid characters)"
        return 1
    fi
    
    # Check for path traversal
    if [[ "$package_name" == *".."* ]] || [[ "$package_name" == *"/"* ]]; then
        err "Invalid package name: $package_name (contains path separators)"
        return 1
    fi
    
    return 0
}

