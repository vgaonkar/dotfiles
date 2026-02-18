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
    echo "  1. Restart your terminal or run: source ~/.bashrc (or ~/.zshrc)"
    echo "  2. The installer prompted you for preferences (default shell, etc.)"
    echo "  3. If you chose fish as default, run: chsh -s \$(which fish)"
    echo "  4. Read the docs: chezmoi cd && cat docs/01-quick-start.md"
    echo ""
else
    echo -e "${RED}❌ Installation failed${NC}"
    echo "Please check the error messages above"
    exit 1
fi
