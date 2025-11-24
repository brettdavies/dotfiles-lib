#!/usr/bin/env bash
# Rollback/undo functionality
# Provides functions for tracking operations and creating rollback scripts
# Requires: lib-core.sh, lib-temp.sh (via lib-core.sh), lib-logging.sh (via lib-core.sh)

# Prevent re-sourcing
if [ -n "${LIB_ROLLBACK_LOADED:-}" ]; then
    return 0
fi
export LIB_ROLLBACK_LOADED=1

# Source core library if not already sourced
# Check if DOTFILES_DIR is defined (indicates lib-core.sh has been sourced)
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi

# Global rollback state
ROLLBACK_INITIALIZED=false
ROLLBACK_SCRIPT=""
ROLLBACK_OPERATIONS=()

# Initialize rollback tracking
# Usage: init_rollback [rollback_script_path]
# Example: init_rollback "$(create_temp_file "rollback.XXXXXX.sh")"
init_rollback() {
    local script_path="${1:-}"
    
    if [ -z "$script_path" ]; then
        script_path=$(create_temp_file "rollback.XXXXXX.sh")
    fi
    
    ROLLBACK_SCRIPT="$script_path"
    ROLLBACK_OPERATIONS=()
    ROLLBACK_INITIALIZED=true
    
    # Create rollback script header
    {
        echo "#!/bin/bash"
        echo "# Rollback script generated on $(date)"
        echo "# This script will undo the operations performed during installation"
        echo ""
        echo "set -euo pipefail"
        echo ""
        echo "echo 'Starting rollback...'"
        echo ""
    } > "$ROLLBACK_SCRIPT"
    
    chmod +x "$ROLLBACK_SCRIPT"
    
    log_debug "Rollback initialized: $ROLLBACK_SCRIPT"
}

# Record an operation for rollback
# Usage: record_operation <operation_type> <description> <command>
# Example: record_operation "symlink" "Created .zshrc symlink" "rm -f ~/.zshrc"
record_operation() {
    local op_type="$1"
    local description="$2"
    local rollback_command="$3"
    
    if [ "$ROLLBACK_INITIALIZED" != true ]; then
        return 0  # Rollback not initialized, skip
    fi
    
    # Add to operations array
    ROLLBACK_OPERATIONS+=("$op_type|$description|$rollback_command")
    
    # Append to rollback script
    {
        echo "# $description"
        echo "$rollback_command" || true
        echo ""
    } >> "$ROLLBACK_SCRIPT"
    
    log_debug "Recorded operation: $description"
}

# Record file backup for rollback
# Usage: record_file_backup <original_path> <backup_path>
# Example: record_file_backup "$HOME/.zshrc" "$backup_dir/.zshrc.backup"
record_file_backup() {
    local original_path="$1"
    local backup_path="$2"
    
    if [ "$ROLLBACK_INITIALIZED" != true ]; then
        return 0
    fi
    
    # Record restore operation
    local restore_command="if [ -f '$backup_path' ]; then mv '$backup_path' '$original_path'; fi"
    record_operation "restore" "Restore $original_path from backup" "$restore_command"
}

# Record symlink creation for rollback
# Usage: record_symlink_creation <symlink_path>
# Example: record_symlink_creation "$HOME/.zshrc"
record_symlink_creation() {
    local symlink_path="$1"
    
    if [ "$ROLLBACK_INITIALIZED" != true ]; then
        return 0
    fi
    
    # Record removal operation
    local remove_command="if [ -L '$symlink_path' ]; then rm -f '$symlink_path'; fi"
    record_operation "remove_symlink" "Remove symlink $symlink_path" "$remove_command"
}

# Record file creation for rollback
# Usage: record_file_creation <file_path>
# Example: record_file_creation "$HOME/.secrets"
record_file_creation() {
    local file_path="$1"
    
    if [ "$ROLLBACK_INITIALIZED" != true ]; then
        return 0
    fi
    
    # Record removal operation
    local remove_command="if [ -f '$file_path' ]; then rm -f '$file_path'; fi"
    record_operation "remove_file" "Remove file $file_path" "$remove_command"
}

# Record directory creation for rollback
# Usage: record_directory_creation <dir_path>
# Example: record_directory_creation "$HOME/.config/git"
record_directory_creation() {
    local dir_path="$1"
    
    if [ "$ROLLBACK_INITIALIZED" != true ]; then
        return 0
    fi
    
    # Record removal operation (only if empty)
    local remove_command="if [ -d '$dir_path' ] && [ -z \"\$(ls -A '$dir_path')\" ]; then rmdir '$dir_path'; fi"
    record_operation "remove_directory" "Remove directory $dir_path" "$remove_command"
}

# Finalize rollback script
# Usage: finalize_rollback [message]
# Example: finalize_rollback "Rollback script ready"
finalize_rollback() {
    local message="${1:-Rollback complete}"
    
    if [ "$ROLLBACK_INITIALIZED" != true ] || [ -z "$ROLLBACK_SCRIPT" ]; then
        return 0
    fi
    
    # Add footer to rollback script
    {
        echo "echo '$message'"
        echo "echo 'Rollback script location: $ROLLBACK_SCRIPT'"
    } >> "$ROLLBACK_SCRIPT"
    
    log_info "Rollback script created: $ROLLBACK_SCRIPT"
    log_info "To undo changes, run: $ROLLBACK_SCRIPT"
}

# Get rollback script path
# Usage: get_rollback_script
# Returns: path to rollback script via echo
get_rollback_script() {
    if [ "$ROLLBACK_INITIALIZED" = true ] && [ -n "$ROLLBACK_SCRIPT" ]; then
        echo -n "$ROLLBACK_SCRIPT"
    else
        echo -n ""
    fi
}

# Execute rollback script
# Usage: execute_rollback [rollback_script_path]
# Example: execute_rollback "$ROLLBACK_SCRIPT"
execute_rollback() {
    local script_path="${1:-$ROLLBACK_SCRIPT}"
    
    if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
        err "Rollback script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        err "Rollback script is not executable: $script_path"
        return 1
    fi
    
    log_info "Executing rollback script: $script_path"
    bash "$script_path"
}

