#!/bin/bash
#
# Test that all Chezmoi template files render without errors
# Uses env vars to avoid interactive prompts
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}Testing Chezmoi template rendering...${NC}"
echo ""

if ! command -v chezmoi &> /dev/null; then
    echo -e "${RED}Warning: 'chezmoi' is not installed — skipping template tests.${NC}"
    exit 0
fi

# Set env vars so .chezmoi.toml.tmpl uses non-interactive paths
export CHEZMOI_DEFAULT_SHELL="bash"
export CHEZMOI_INSTALL_TOOLS="false"
export CHEZMOI_WORK_MACHINE="false"

PASS=0
FAIL=0
FAILURES=()

test_template() {
    local file="$1"
    local rel="${file#"${REPO_ROOT}/"}"

    if chezmoi execute-template < "$file" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} ${rel}"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} ${rel}"
        FAILURES+=("$rel")
        FAIL=$((FAIL + 1))
    fi
}

# Collect all .tmpl files, excluding:
#   .chezmoi.toml.tmpl  — config template using promptStringOnce/promptBoolOnce,
#                         not renderable via execute-template
#   .chezmoitemplates/  — partial templates included by others, not standalone
mapfile -t tmpl_files < <(
    find "${REPO_ROOT}" \
        -not -path "${REPO_ROOT}/.git/*" \
        -not -path "${REPO_ROOT}/.chezmoitemplates/*" \
        -not -name ".chezmoi.toml.tmpl" \
        -name "*.tmpl" \
        | sort
)

if [ ${#tmpl_files[@]} -eq 0 ]; then
    echo -e "${GREEN}No template files found.${NC}"
    exit 0
fi

echo "Found ${#tmpl_files[@]} template(s) to test."
echo ""

for f in "${tmpl_files[@]}"; do
    test_template "$f"
done

echo ""
if [ ${#FAILURES[@]} -gt 0 ]; then
    echo -e "${RED}Failed templates:${NC}"
    for f in "${FAILURES[@]}"; do
        echo "  - ${f}"
    done
    echo ""
fi

if [ "${FAIL}" -eq 0 ]; then
    echo -e "${GREEN}All ${PASS} template(s) rendered successfully.${NC}"
    exit 0
else
    echo -e "${RED}${FAIL} template(s) failed, ${PASS} passed.${NC}"
    exit 1
fi
