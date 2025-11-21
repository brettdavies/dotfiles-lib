#!/bin/bash
# Sync-local helper functions
# Provides functions for syncing local changes back into the dotfiles repository
# Requires: lib-core.sh (for DOTFILES_DIR variable)

# Source core library if not already sourced
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# Detect if a file is binary
# Usage: is_binary_file <file_path>
# Returns: 0 if binary, 1 if text
is_binary_file() {
    local file="$1"
    
    # Check if file exists
    [ -f "$file" ] || return 1
    
    # Use file command if available
    if command -v file &> /dev/null; then
        local file_type
        file_type=$(file -b --mime-type "$file" 2>/dev/null || echo "")
        if [[ "$file_type" =~ ^(image|video|audio|application)/ ]] || [[ "$file_type" == "application/octet-stream" ]]; then
            return 0
        fi
        # Check for text types explicitly
        if [[ "$file_type" =~ ^text/ ]] || [[ "$file_type" == "application/json" ]] || [[ "$file_type" == "application/xml" ]]; then
            return 1
        fi
    fi
    
    # Fallback: check common binary extensions
    local ext="${file##*.}"
    case "$ext" in
        png|jpg|jpeg|gif|bmp|ico|svg|webp|pdf|zip|tar|gz|bz2|xz|exe|dll|so|dylib|bin|o|a|pyc|pyo|class|jar|war|ear|deb|rpm|dmg|pkg|app|ipa|apk)
            return 0
            ;;
    esac
    
    # Default to text file
    return 1
}

# Compare two files
# Usage: compare_files <file1> <file2>
# Returns: 0 if identical, 1 if different
compare_files() {
    local file1="$1"
    local file2="$2"
    
    # Both files must exist
    [ -f "$file1" ] && [ -f "$file2" ] || return 1
    
    # Use cmp for binary-safe comparison
    cmp -s "$file1" "$file2" 2>/dev/null
}

# Show diff between two files in git unified diff format
# Usage: show_file_diff <file1> <file2> [label1] [label2]
# Shows diff in git unified format (like git diff)
show_file_diff() {
    local file1="$1"
    local file2="$2"
    local label1="${3:-a/$file1}"
    local label2="${4:-b/$file2}"
    
    # Use git diff if available (produces better output)
    if command -v git &> /dev/null; then
        git diff --no-index --no-color -- "$file1" "$file2" 2>/dev/null | sed "1s|^---.*|--- $label1|; 2s|^+++.*|+++ $label2|" || true
    else
        # Fallback to diff -u
        diff -u --label "$label1" --label "$label2" "$file1" "$file2" 2>/dev/null || true
    fi
}

# Copy local file to repo location with proper path transformation
# Usage: copy_to_repo <local_file> <repo_file>
# Creates parent directories if needed
copy_to_repo() {
    local local_file="$1"
    local repo_file="$2"
    
    # Create parent directory if needed
    local repo_dir
    repo_dir=$(dirname "$repo_file")
    mkdir -p "$repo_dir"
    
    # Copy file
    cp "$local_file" "$repo_file"
}

# Create backup of a file
# Usage: create_file_backup <file_path>
# Creates backup in .backup/ directory with timestamp
# Returns: backup path via echo
create_file_backup() {
    local file="$1"
    local backup_dir="$DOTFILES_DIR/.backup"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local filename
    filename=$(basename "$file")
    local rel_path
    rel_path="${file#$DOTFILES_DIR/}"
    local backup_path="$backup_dir/$rel_path.$timestamp"
    
    # Create backup directory structure
    mkdir -p "$(dirname "$backup_path")"
    
    # Copy file to backup
    cp "$file" "$backup_path"
    
    echo "$backup_path"
}

# Merge two files using diff3
# Usage: merge_files <local_file> <repo_file> <output_file>
# Returns: 0 if merge successful, 1 if conflicts
merge_files() {
    local local_file="$1"
    local repo_file="$2"
    local output_file="$3"
    
    # Use diff3 if available
    if command -v diff3 &> /dev/null; then
        # Create a temporary base file (empty for now, could be improved)
        local base_file
        base_file=$(mktemp)
        trap "rm -f '$base_file'" EXIT
        
        # Try merge
        if diff3 -m "$local_file" "$base_file" "$repo_file" > "$output_file" 2>/dev/null; then
            rm -f "$base_file"
            # Check if output contains conflict markers
            if grep -q "^<<<<<<< " "$output_file" 2>/dev/null; then
                return 1  # Conflicts found
            fi
            return 0  # Merge successful
        else
            rm -f "$base_file"
            return 1  # Merge failed
        fi
    else
        # Fallback: just copy local file (no merge)
        cp "$local_file" "$output_file"
        return 0
    fi
}

