#!/bin/bash
#
# Import existing dotfiles into chezmoi
# Run this to import your current configs
#

set -euo pipefail

echo "📥 Importing existing dotfiles..."

# List of common dotfiles to import
FILES=(
    "$HOME/.bashrc"
    "$HOME/.bash_profile"
    "$HOME/.profile"
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.gitconfig"
    "$HOME/.ssh/config"
)

# Import each file if it exists
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Importing: $file"
        chezmoi add "$file"
    fi
done

# Import Fish config if it exists
if [ -d "$HOME/.config/fish" ]; then
    echo "Importing Fish config..."
    chezmoi add "$HOME/.config/fish/config.fish"
    
    # Import fish functions
    if [ -d "$HOME/.config/fish/functions" ]; then
        for func in "$HOME/.config/fish/functions/"*.fish; do
            if [ -f "$func" ]; then
                echo "Importing function: $(basename "$func")"
                chezmoi add "$func"
            fi
        done
    fi
fi

# Import other configs
CONFIGS=(
    "$HOME/.config/starship.toml"
    "$HOME/.config/atuin/config.toml"
)

for config in "${CONFIGS[@]}"; do
    if [ -f "$config" ]; then
        echo "Importing: $config"
        chezmoi add "$config"
    fi
done

echo ""
echo "✅ Import complete!"
echo "Review the changes with: chezmoi diff"
echo "Apply with: chezmoi apply"
