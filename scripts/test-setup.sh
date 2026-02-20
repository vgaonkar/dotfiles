#!/bin/bash
#
# Test dotfiles setup
# Verifies that everything is installed and working
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing dotfiles setup...${NC}"
echo ""

# Track failures
FAILURES=0

# Function to test a command
test_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name: $(which "$cmd")"
        return 0
    else
        echo -e "${RED}✗${NC} $name: NOT FOUND"
        ((FAILURES++))
        return 1
    fi
}

echo -e "${BLUE}Checking tools:${NC}"
test_command "chezmoi" "Chezmoi"
test_command "starship" "Starship"
test_command "zoxide" "Zoxide"
test_command "eza" "Eza"
test_command "bat" "Bat"
test_command "fzf" "FZF"
test_command "direnv" "Direnv"
test_command "atuin" "Atuin"
test_command "gh" "GitHub CLI"

# Check GitHub CLI auth status
if command -v gh &> /dev/null; then
    if gh auth status --hostname github.com &> /dev/null; then
        echo -e "${GREEN}✓${NC} GitHub Auth: Authenticated"
    else
        echo -e "${YELLOW}!${NC} GitHub Auth: Not authenticated (run 'gh auth login')"
    fi
fi

echo ""
echo -e "${BLUE}Checking shells:${NC}"
test_command "bash" "Bash"
test_command "zsh" "Zsh"
test_command "fish" "Fish"

echo ""
echo -e "${BLUE}Checking dotfiles:${NC}"

# Check managed files
MANAGED_FILES=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.config/fish/config.fish"
    "$HOME/.config/starship.toml"
)

for file in "${MANAGED_FILES[@]}"; do
    if [ -L "$file" ] || chezmoi managed "$file" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Managed: $(basename "$file")"
    else
        echo -e "${YELLOW}!${NC} Not managed: $(basename "$file")"
    fi
done

echo ""
if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ $FAILURES test(s) failed${NC}"
    exit 1
fi
