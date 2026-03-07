#!/bin/bash
#
# Run all test scripts in sequence
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Dotfiles Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

PASS=0
FAIL=0
FAILURES=()

run_suite() {
    local name="$1"
    local script="$2"

    echo -e "${BLUE}--- ${name} ---${NC}"
    if bash "$script"; then
        PASS=$((PASS + 1))
    else
        FAILURES+=("$name")
        FAIL=$((FAIL + 1))
    fi
    echo ""
}

run_suite "Template Rendering" "${SCRIPT_DIR}/test-templates.sh"
run_suite "ShellCheck"         "${SCRIPT_DIR}/test-shellcheck.sh"

echo -e "${BLUE}========================================${NC}"
if [ "${FAIL}" -eq 0 ]; then
    echo -e "${GREEN}All ${PASS} suite(s) passed.${NC}"
    exit 0
else
    echo -e "${RED}${FAIL} suite(s) failed:${NC}"
    for s in "${FAILURES[@]}"; do
        echo "  - ${s}"
    done
    exit 1
fi
