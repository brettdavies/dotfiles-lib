#!/usr/bin/env bash
# BATS test runner script
# Runs all BATS tests in the test directory

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
    echo "Error: BATS is not installed." >&2
    echo "Install with: brew install bats-core (macOS) or see https://github.com/bats-core/bats-core" >&2
    exit 1
fi

# Check if bats-support and bats-assert are installed
if [ ! -d "/usr/local/lib/bats-support" ] && [ ! -d "$HOME/.local/lib/bats-support" ]; then
    echo "Warning: bats-support and bats-assert may not be installed." >&2
    echo "Install with: git clone https://github.com/bats-core/bats-support.git /usr/local/lib/bats-support" >&2
    echo "             git clone https://github.com/bats-core/bats-assert.git /usr/local/lib/bats-assert" >&2
    echo "             git clone https://github.com/bats-core/bats-file.git /usr/local/lib/bats-file" >&2
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Running BATS tests...${NC}"
echo ""

# Run all BATS tests
if bats "$TEST_DIR"/*.bats; then
    echo ""
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

