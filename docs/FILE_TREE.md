# Repository File Tree

This document provides a complete overview of the repository structure. **All developers MUST reference this file** when making changes to ensure consistency and proper file organization.

## Current Repository Structure

```plaintext
dotfiles/
├── install.sh                            # Main installation orchestrator
├── README.md                             # User-facing documentation
├── docs/                                 # Documentation directory
│   ├── FILE_TREE.md                      # This file - repository structure reference
│   └── ARCHITECTURE.md                   # Architecture documentation
│  
└── scripts/  
    ├── lib/                              # Shared library functions
    │   ├── lib-core.sh                   # Main orchestrator (loads all core libraries)
    │   ├── lib-constants.sh              # Color and permission constants
    │   ├── lib-os.sh                     # OS and shell detection
    │   ├── lib-paths.sh                  # Path utilities and common variables
    │   ├── lib-args.sh                   # Common argument parsing
    │   ├── lib-verbose.sh                # Verbose output helpers
    │   ├── lib-shell.sh                  # Modern shell features (readarray helpers)
    │   ├── lib-errors.sh                 # Error handling and reporting
    │   ├── lib-logging.sh                # Structured logging system
    │   ├── lib-temp.sh                   # Temporary directory management (single directory per script)
    │   ├── lib-filesystem.sh             # File system operations (find, cache, etc.)
    │   ├── lib-progress.sh               # Progress indicators (ConEmu OSC 9;4)
    │   ├── lib-validation.sh             # Input validation and sanitization
    │   ├── lib-rollback.sh               # Rollback/undo functionality
    │   ├── lib-file.sh                   # File operations
    │   ├── lib-packages.sh               # Package checking with caching
    │   ├── lib-stow.sh                   # Stow operations
    │   └── lib-sync.sh                   # Sync operations
    │  
    ├── install/                          # Installation scripts
    │   ├── check-dependencies.sh         # Check and install dependencies
    │   ├── stow-packages.sh              # Create symlinks using stow
    │   ├── create-secrets.sh             # Create .secrets file
    │   ├── create-lmstudio-pointer.sh    # Create LM Studio pointer file
    │   └── install-packages.sh           # Install packages from Brewfile
    │  
    ├── check/                            # Verification scripts
    │   └── check-implementation.sh       # Verify dotfiles are fully implemented
    │  
    └── test/                             # Test scripts
        ├── test-in-docker.sh             # Test installation in Docker containers
        └── bats/                         # BATS test framework tests
            ├── test_helper.bash          # Test helper functions
            ├── run_tests.sh              # Test runner script
            ├── README.md                 # BATS test suite documentation
            ├── test_lib_core.bats        # Core library tests
            ├── test_lib_file.bats        # File operations tests
            ├── test_lib_temp.bats        # Temp management tests
            ├── test_lib_errors.bats      # Error handling tests
            ├── test_lib_logging.bats     # Logging tests
            ├── test_lib_validation.bats  # Validation tests
            ├── test_lib_stow.bats        # Stow operations tests
            ├── test_lib_packages.bats    # Package checking tests
            ├── test_lib_filesystem.bats  # Filesystem operations tests
            ├── test_lib_sync.bats        # Sync operations tests
            ├── test_lib_progress.bats    # Progress indicator tests
            └── test_lib_rollback.bats    # Rollback functionality tests
│ 
└── stow/                                 # Stow packages (dotfile configurations)
    ├── bash/                             # Bash configs
    ├── brew/                             # Brewfile and package definitions
    ├── claude/                           # Claude IDE configs
    ├── codex/                            # Codex configs
    ├── cursor/                           # Cursor configs and extensions
    ├── gh/                               # GitHub CLI configs
    ├── ghostty/                          # Ghostty terminal config
    ├── git/                              # Git configs
    ├── local/                            # Local bin configs
    ├── opencode/                         # OpenCode configs
    ├── ssh/                              # SSH config
    ├── telemetry/                        # Telemetry settings
    └── zsh/                              # Zsh configs
```

## File Organization Principles

### Directory Structure

1. **`scripts/lib/`** - All shared library functions
   - Each file has a single, clear responsibility (SRP)
   - Functions are small, focused, and reusable (DRY, STAR)
   - Dependencies between files are minimized

2. **`scripts/install/`** - Installation and setup scripts
   - Scripts that modify the system or create files
   - Each script handles one specific installation task

3. **`scripts/check/`** - Verification and validation scripts
   - Scripts that check system state without modifying it
   - Used for verification and reporting

4. **`scripts/test/`** - Test scripts
   - Automated tests and test infrastructure
   - Docker-based integration tests

### Naming Conventions

- **Library files**: `lib-<purpose>.sh` (e.g., `lib-core.sh`, `lib-packages.sh`)
- **Installation scripts**: Descriptive names (e.g., `stow-packages.sh`, `install-packages.sh`)
- **Check scripts**: `check-<purpose>.sh` (e.g., `check-implementation.sh`)
- **Test scripts**: `test-<purpose>.sh` (e.g., `test-in-docker.sh`)

### Source Path Conventions

All scripts should source libraries using the following pattern:

```bash
# For scripts in subdirectories (install/, check/, test/)
SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPTS_DIR/lib/lib-core.sh"
source "$SCRIPTS_DIR/lib/lib-<other>.sh"

# For library files in lib/
# They can use relative paths since they're in the same directory
if [ -z "${DOTFILES_DIR:-}" ]; then
    source "$(dirname "$0")/lib-core.sh"
fi
```

## Migration Notes

### Files Moved (Completed)

The following files were moved from `scripts/` to subdirectories:

- `lib-*.sh` → `scripts/lib/`
- `check-dependencies.sh` → `scripts/install/`
- `create-*.sh` → `scripts/install/`
- `install-packages.sh` → `scripts/install/`
- `stow-packages.sh` → `scripts/install/`
- `check-implementation.sh` → `scripts/check/`
- `test-in-docker.sh` → `scripts/test/`

### Path Updates Required

All scripts have been updated to use the new paths:

- `install.sh` now references `scripts/lib/`, `scripts/install/`, `scripts/check/`
- All scripts in subdirectories use `SCRIPTS_DIR` variable to reference `lib/`
- Library files use relative paths within `lib/` directory

## Developer Guidelines

**CRITICAL**: When adding new files:

1. **Reference this file tree** to determine the correct location
2. **Follow the naming conventions** for consistency
3. **Update this file tree** when adding new files or directories
4. **Update source paths** in any scripts that reference moved files
5. **Test path resolution** to ensure scripts can find their dependencies

### Adding New Library Files

1. Place in `scripts/lib/`
2. Follow naming: `lib-<purpose>.sh`
3. Source `lib-core.sh` if needed (use relative path within `lib/`)
4. Update this file tree

### Adding New Installation Scripts

1. Place in `scripts/install/`
2. Source libraries using `SCRIPTS_DIR` pattern
3. Update `install.sh` if it should be called automatically
4. Update this file tree

### Adding New Check Scripts

1. Place in `scripts/check/`
2. Source libraries using `SCRIPTS_DIR` pattern
3. Update this file tree

### Adding New Test Scripts

1. Place in `scripts/test/`
2. Source libraries using `SCRIPTS_DIR` pattern
3. Update this file tree

## Status Legend

- **EXISTS** - File currently exists in repository
- 🔜 **PLANNED** - File planned for future implementation
- ⚠️ **DEPRECATED** - File exists but is deprecated (will be removed)
