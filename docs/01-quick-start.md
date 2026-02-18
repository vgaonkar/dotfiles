# Quick Start

Get your development environment set up in minutes. These dotfiles use [Chezmoi](https://www.chezmoi.io/) to manage configurations across different operating systems.

## One-Line Install

Open your terminal and run the command for your platform.

### macOS & Linux

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply vgaonkar
```

### Windows (PowerShell)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://git.io/chezmoi.ps1')); chezmoi init --apply vgaonkar"
```

## What Happens Next

The installation script performs several automated tasks:

1. Installs Chezmoi if it's not already on your system.
2. Initializes a local repository in `~/.local/share/chezmoi`.
3. Pulls the latest configurations from the remote repository.
4. Applies the files to your home directory.

## First Steps

Once the installation finishes, you should:

- **Restart your terminal:** This ensures all new aliases and environment variables are loaded.
- **Run the setup script:** If prompted, run `~/scripts/setup.sh` to install system-specific dependencies like Homebrew packages or Apt tools.
- **Check your editor:** Open Neovim or VS Code to verify that plugins are installing correctly.

## Next Steps

For a deeper dive into the prerequisites, platform-specific notes, and manual installation steps, head over to the [Detailed Installation Guide](02-installation.md).
