#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Linting Shell Scripts...${NC}"

if ! command -v shellcheck &> /dev/null; then
    echo -e "${RED}Error: 'shellcheck' is not installed.${NC}"
    echo "Please install it to run linting checks."
    exit 1
fi

mapfile -t files < <(find scripts -name "*.sh")


if [ ${#files[@]} -eq 0 ]; then
    echo -e "${GREEN}No shell scripts found to lint.${NC}"
    exit 0
fi

echo "Found ${#files[@]} script(s) to check."

if shellcheck "${files[@]}"; then
    echo -e "${GREEN}✅ ShellCheck passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ ShellCheck failed.${NC}"
    exit 1
fi
