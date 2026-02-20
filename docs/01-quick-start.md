# Quick Start

Get your development environment set up in minutes. These dotfiles use [Chezmoi](https://www.chezmoi.io/) to manage configurations across different operating systems.

## One-Line Install

Open your terminal and run the command for your platform.

### macOS & Linux

#### Browser Login (Private Repo)

If you don't have SSH keys set up, use this method to authenticate via your browser. This uses the GitHub CLI (`gh`) to handle authentication.

```bash
curl -fsLS https://gist.githubusercontent.com/vgaonkar/072d89db4a77cd02d542191f89ad1e19/raw/65b6aa3e35400aea2e3fbca59803a6816974c0cb/install.sh | bash
```

*Note: The URL is pinned to a specific gist revision and should be updated when the script changes.*

#### Standard Install

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply vgaonkar
```

**Note:** GitHub requires SSH authentication or a Personal Access Token. If you get an authentication error, see the [SSH Setup Guide](02-installation.md#github-authentication-ssh) first.

Alternative using SSH (recommended):
```bash
sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply git@github.com:vgaonkar/dotfiles.git
```

### Windows (PowerShell)

#### Browser Login (Private Repo)

If you don't have SSH keys set up, use this method to authenticate via your browser.

```powershell
irm https://gist.githubusercontent.com/vgaonkar/072d89db4a77cd02d542191f89ad1e19/raw/65b6aa3e35400aea2e3fbca59803a6816974c0cb/install.ps1 | iex
```

*Note: The URL is pinned to a specific gist revision and should be updated when the script changes.*

#### Standard Install

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
