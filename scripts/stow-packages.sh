#!/bin/bash
# Stow all dotfiles packages to create symlinks
#
# Uses stow --dotfiles for all packages except VS Code (see exception in code).
# The --dotfiles option converts dot-* prefixes to .* prefixes automatically.

set -e

# Source shared library
source "$(dirname "$0")/lib.sh"

# Function to remove existing files/directories that would conflict with symlinks
# This is a prerequisite step before stow can create symlinks safely
# Stow will fail if target files/directories already exist and aren't symlinks
# This function handles the --dotfiles transformation (dot-* -> .*)
remove_conflicting_files() {
    local package=$1
    local target=$2
    
    # Find all files in the package directory
    if [ ! -d "$package" ]; then
        return 0  # Package doesn't exist, nothing to remove
    fi
    
    find "$package" -type f | while read -r file; do
        # Get relative path from package directory
        rel_path="${file#$package/}"
        
        # Apply --dotfiles transformation: convert dot-* prefixes to .* prefixes
        # This matches what stow --dotfiles does
        transformed_path=$(echo "$rel_path" | sed 's|dot-|.|g')
        
        # Construct target path with transformed path
        target_file="$target/$transformed_path"
        
        # If target exists and is not a symlink, remove it
        if [ -e "$target_file" ] && [ ! -L "$target_file" ]; then
            echo "    Removing existing: $target_file"
            rm -rf "$target_file"
        fi
    done
}

# Function to stow a package with dotfiles support
# Uses stow's --dotfiles option which converts dot-* prefixes to .* prefixes
# This allows us to keep files visible in the stow directory (with dot- prefix)
# while creating proper hidden dotfiles (with . prefix) in the home directory
stow_package() {
    local package=$1
    
    if [ ! -d "$STOW_DIR/$package" ]; then
        return 0  # Package doesn't exist
    fi
    
    # Remove conflicting files first
    remove_conflicting_files "$STOW_DIR/$package" ~
    
    # Use stow with --dotfiles option to handle dot-* prefixes
    cd "$STOW_DIR"
    stow --dotfiles -t ~ "$package" 2>/dev/null || true
}

# Main execution
echo -e "${GREEN}Creating symlinks...${NC}"

# Shell configs
echo "  - Shell configs (zsh, bash)"
stow_package zsh
stow_package bash

# Git configs
echo "  - Git configs"
stow_package git

# SSH config
echo "  - SSH config"
stow_package ssh

# Terminal configs
echo "  - Terminal configs (ghostty)"
stow_package ghostty

# GitHub CLI configs
echo "  - GitHub CLI configs"
stow_package gh

# oh-my-zsh customizations
echo "  - oh-my-zsh customizations"
stow_package oh-my-zsh

# Local bin configs
echo "  - Local bin configs"
stow_package local

# Claude IDE configs
echo "  - Claude IDE configs"
stow_package claude

# Codex configs
echo "  - Codex configs"
stow_package codex

# Cursor configs
echo "  - Cursor configs"
stow_package cursor

# OpenCode configs
echo "  - OpenCode configs"
stow_package opencode

# Telemetry settings
echo "  - Telemetry settings"
stow_package telemetry

# VS Code settings (macOS specific)
# EXCEPTION: Uses regular stow (not --dotfiles) because:
# 1. VS Code settings are in a non-standard location (~/Library/Application Support/Code/User)
# 2. Files don't need dot prefix restoration (they're not dotfiles)
# 3. We stow from inside the vscode directory to target the correct path structure
if [[ "$OS" == "macos" ]]; then
    echo "  - VS Code settings"
    VS_CODE_DIR="$HOME/Library/Application Support/Code/User"
    if [ ! -d "$VS_CODE_DIR" ]; then
        mkdir -p "$VS_CODE_DIR"
    fi
    # Remove conflicting files
    if [ -d "$STOW_DIR/vscode" ]; then
        find "$STOW_DIR/vscode" -type f | while read -r file; do
            rel_path="${file#$STOW_DIR/vscode/}"
            target_file="$VS_CODE_DIR/$rel_path"
            if [ -e "$target_file" ] && [ ! -L "$target_file" ]; then
                echo "    Removing existing: $target_file"
                rm -rf "$target_file"
            fi
        done
    fi
    # Stow from vscode directory, targeting Library/Application Support/Code/User
    cd "$STOW_DIR/vscode"
    stow -t "$VS_CODE_DIR" . 2>/dev/null || true
    cd "$STOW_DIR"
fi

