#!/bin/bash
#
# Dotfiles Installer for macOS and Linux
# This script installs chezmoi and applies the dotfiles
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository configuration
GITHUB_USER="vgaonkar"
DOTFILES_REPO="https://github.com/${GITHUB_USER}/dotfiles.git"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

BROWSER_LOGIN=false
for arg in "$@"; do
    case "$arg" in
        --browser-login)
            BROWSER_LOGIN=true
            ;;
        -h|--help)
            echo "Usage: $(basename -- "${BASH_SOURCE[0]}") [--browser-login]"
            echo ""
            echo "  --browser-login   Use GitHub CLI web login (HTTPS) bootstrap"
            exit 0
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown argument: $arg" >&2
            echo "Run with --help for usage" >&2
            exit 2
            ;;
    esac
done

if [ "$BROWSER_LOGIN" = true ]; then
    echo -e "${YELLOW}Using browser-login (HTTPS) bootstrap...${NC}"
    exec bash "$SCRIPT_DIR/bootstrap/install.sh"
fi

echo -e "${BLUE}🏠 Dotfiles Installer${NC}"
echo ""

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)

echo -e "${BLUE}Detected:${NC} $OS ($ARCH)"

# Install chezmoi if not present
if ! command -v chezmoi &> /dev/null; then
    echo -e "${YELLOW}📦 Installing chezmoi...${NC}"
    sh -c "$(curl -fsLS get.chezmoi.io)"
else
    echo -e "${GREEN}✓ chezmoi already installed${NC}"
fi

# Make sure chezmoi is in PATH
if [ -x "$HOME/.local/bin/chezmoi" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Initialize and apply dotfiles
echo -e "${YELLOW}🚀 Initializing dotfiles...${NC}"
echo -e "${BLUE}Repository:${NC} $DOTFILES_REPO"
echo ""

if chezmoi init --apply "$GITHUB_USER"; then
    echo ""
    echo -e "${GREEN}✅ Dotfiles installed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Restart your terminal or run: source ~/.config/fish/config.fish"
    echo "  2. The installer sets fish as the default shell (verify with: echo \$SHELL)"
    echo "  3. If needed, set login shell manually: chsh -s \$(which fish)"
    echo "  4. If using zsh/bash instead, reload with: source ~/.zshrc or source ~/.bashrc"
    echo "  5. Read the docs: chezmoi cd && cat docs/01-quick-start.md"
    echo ""
else
    echo -e "${RED}❌ Installation failed${NC}"
    echo "Please check the error messages above"
    exit 1
fi
