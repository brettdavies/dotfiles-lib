#!/bin/bash
# Create .secrets file with proper permissions

set -e

# Source shared library
source "$(dirname "$0")/lib.sh"

# Main execution
echo "  - Creating .secrets file"
if [ ! -f ~/.secrets ]; then
    touch ~/.secrets
    chmod 600 ~/.secrets
    echo -e "${GREEN}    Created empty .secrets file with 600 permissions${NC}"
else
    echo -e "${YELLOW}    .secrets file already exists, skipping${NC}"
fi

