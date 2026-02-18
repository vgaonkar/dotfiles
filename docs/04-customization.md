# Personalizing Your Setup

This guide covers how to customize your dotfiles without conflicting with future updates from the main repository.

## Custom Aliases and Functions

While we provide a robust set of defaults, you likely have personal shortcuts.

### Adding Personal Aliases

Create a file named `.aliases.local` in your home directory. The shell configuration is set to automatically source this file if it exists.

```bash
# ~/.aliases.local
alias gcap='git commit -a -p'
alias dc='docker-compose'
```

### Adding Custom Functions

Similarly, you can create a `.functions.local` file for more complex logic:

```bash
# ~/.functions.local
function mkcd() {
  mkdir -p "$1" && cd "$1"
}
```

## Modifying the Starship Prompt

We use [Starship](https://starship.rs/) for a fast and customizable prompt.

To tweak the prompt:
1. Open `~/.config/starship.toml`.
2. Modify existing modules or add new ones.
3. Changes take effect in new shell sessions, or by running `exec zsh`.

Example: Changing the directory truncation length
```toml
[directory]
truncation_length = 5
```

## Adding New Tools

If you want to add a tool to the automatic installation list:

1. Locate the installation script for your OS (e.g., `install_macos.sh` or `install_linux.sh`).
2. Add the package name to the relevant list.
3. Run `chezmoi apply` to ensure everything is synced.

## Excluding Files

If there are parts of the template you don't want on a specific machine, use a `.chezmoiignore` file.

Example: Don't sync work-related configs on a personal machine
```text
.config/work-tool/**
.ssh/id_work
```

## Best Practices

- **Keep it Modular**: Use separate files for different concerns (git, shell, tools).
- **Document Your Changes**: Add comments to your local files explaining why a customization exists.
- **Use `chezmoi edit`**: Use this command to modify files managed by Chezmoi. It will open the source file in your editor and apply changes once you save.

Next: [Common Issues & Fixes](05-troubleshooting.md)
