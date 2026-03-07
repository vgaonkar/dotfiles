#!/bin/bash
#
# Comprehensive ShellCheck test
# Checks all .sh files and shell-template (.tmpl) rendered output
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo -e "${BLUE}Running comprehensive ShellCheck...${NC}"
echo ""

if ! command -v shellcheck &> /dev/null; then
    echo -e "${RED}Error: 'shellcheck' is not installed.${NC}"
    echo "Please install it to run shellcheck tests."
    exit 1
fi

PASS=0
FAIL=0
FAILURES=()

check_file() {
    local file="$1"
    local label="$2"

    if shellcheck "$file" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} ${label}"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} ${label}"
        FAILURES+=("$label")
        FAIL=$((FAIL + 1))
        # Show the actual errors for context
        shellcheck "$file" 2>&1 | sed 's/^/      /' || true
    fi
}

# --- Static .sh files ---
echo -e "${BLUE}Static shell scripts:${NC}"

mapfile -t sh_files < <(
    find "${REPO_ROOT}" \
        -not -path "${REPO_ROOT}/.git/*" \
        -name "*.sh" \
        | sort
)

if [ ${#sh_files[@]} -eq 0 ]; then
    echo "  (none found)"
else
    for f in "${sh_files[@]}"; do
        check_file "$f" "${f#"${REPO_ROOT}/"}"
    done
fi

# --- Shell templates rendered through chezmoi ---
echo ""
echo -e "${BLUE}Shell templates (rendered):${NC}"

if ! command -v chezmoi &> /dev/null; then
    echo -e "  ${RED}Warning: 'chezmoi' not installed — skipping template rendering checks.${NC}"
else
    export CHEZMOI_DEFAULT_SHELL="bash"
    export CHEZMOI_INSTALL_TOOLS="false"
    export CHEZMOI_WORK_MACHINE="false"

    # Shell config templates: name -> target shell for shellcheck
    # SC1090/SC1091: dynamic/missing source targets are expected in dotfiles
    # SC2034: zsh variables like SAVEHIST look "unused" to shellcheck
    TMPDIR_RENDER="$(mktemp -d)"
    trap 'rm -rf "${TMPDIR_RENDER}"' EXIT

    declare -A SHELL_TMPL_MAP
    SHELL_TMPL_MAP["dot_bashrc.tmpl"]="bash"
    SHELL_TMPL_MAP["dot_bash_profile.tmpl"]="bash"
    SHELL_TMPL_MAP["dot_profile.tmpl"]="sh"
    SHELL_TMPL_MAP["dot_zshrc.tmpl"]="bash"     # no zsh dialect; bash is closest
    SHELL_TMPL_MAP["dot_zprofile.tmpl"]="bash"  # no zsh dialect; bash is closest

    found_any=false
    for tmpl_name in "${!SHELL_TMPL_MAP[@]}"; do
        tmpl_path="${REPO_ROOT}/${tmpl_name}"
        if [ ! -f "$tmpl_path" ]; then
            continue
        fi
        found_any=true

        target_shell="${SHELL_TMPL_MAP[$tmpl_name]}"
        rendered="${TMPDIR_RENDER}/${tmpl_name%.tmpl}.sh"

        if ! chezmoi execute-template < "$tmpl_path" > "$rendered" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} ${tmpl_name} (render failed)"
            FAILURES+=("${tmpl_name} (render failed)")
            FAIL=$((FAIL + 1))
            continue
        fi

        # SC1090/SC1091: can't follow dynamic/external source — expected in dotfiles
        # SC2034: variables set for shell use (e.g. SAVEHIST in zsh) look unused to shellcheck
        if shellcheck --shell="${target_shell}" \
                      --exclude=SC1090,SC1091,SC2034 \
                      "$rendered" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} ${tmpl_name} (rendered, shell=${target_shell})"
            PASS=$((PASS + 1))
        else
            echo -e "  ${RED}✗${NC} ${tmpl_name} (rendered, shell=${target_shell})"
            FAILURES+=("${tmpl_name} (rendered)")
            FAIL=$((FAIL + 1))
            shellcheck --shell="${target_shell}" \
                       --exclude=SC1090,SC1091,SC2034 \
                       "$rendered" 2>&1 | sed 's/^/      /' || true
        fi
    done

    if [ "$found_any" = "false" ]; then
        echo "  (no shell templates found)"
    fi
fi

echo ""
if [ ${#FAILURES[@]} -gt 0 ]; then
    echo -e "${RED}Failed checks:${NC}"
    for f in "${FAILURES[@]}"; do
        echo "  - ${f}"
    done
    echo ""
fi

if [ "${FAIL}" -eq 0 ]; then
    echo -e "${GREEN}All ${PASS} shellcheck(s) passed.${NC}"
    exit 0
else
    echo -e "${RED}${FAIL} shellcheck(s) failed, ${PASS} passed.${NC}"
    exit 1
fi
