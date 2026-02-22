# Installation Guide

This document provides a detailed walkthrough for installing and verifying your new development environment.

## Prerequisites

Before running the installation, ensure your system meets these basic requirements.

### macOS
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew (recommended): `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Linux (Ubuntu/Debian)
- Curl: `sudo apt install curl`
- Linuxbrew/Homebrew (required for default tool setup): `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Windows
- Git for Windows
- PowerShell 7 (highly recommended)
- Windows Terminal


### GitHub Authentication (SSH & Browser)

GitHub no longer supports password authentication for Git operations. You must use SSH, a browser-based login via the GitHub CLI, or a Personal Access Token.

#### No SSH / Browser Login (Private Repo)

This is the easiest method for private repositories when SSH is not yet configured. It uses `gh auth login --web` with the `repo` scope and configures git via `gh auth setup-git`.

**macOS / Linux:**
```bash
curl -fsLS https://gist.githubusercontent.com/vgaonkar/072d89db4a77cd02d542191f89ad1e19/raw/65b6aa3e35400aea2e3fbca59803a6816974c0cb/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://gist.githubusercontent.com/vgaonkar/072d89db4a77cd02d542191f89ad1e19/raw/65b6aa3e35400aea2e3fbca59803a6816974c0cb/install.ps1 | iex
```

*Note: These URLs are pinned to a specific gist revision SHA and should be updated when the gist changes.*

#### Setting up SSH (Recommended)

1. **Check for existing SSH keys:**
   ```bash
   ls -la ~/.ssh/
   ```

2. **Generate a new SSH key (if needed):**
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```

3. **Add to SSH agent:**
   ```bash
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

4. **Copy your public key:**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

5. **Add to GitHub:**
   - Go to: https://github.com/settings/keys
   - Click "New SSH key"
   - Paste your key and save

6. **Install dotfiles via SSH:**
   ```bash
   sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply git@github.com:vgaonkar/dotfiles.git
   ```

#### Alternative: Personal Access Token

If you prefer not to use SSH:
1. Create a token at: https://github.com/settings/tokens
2. Use the token as your password when prompted

## Step-by-Step Installation

### 1. Initialize Chezmoi
If you prefer to review the changes before applying them, run the initialization without the apply flag:

```bash
chezmoi init vgaonkar
```

### 2. Review Changes
See exactly what files will be created or modified in your home directory:

```bash
chezmoi diff
```

### 3. Apply Configurations
Once you're satisfied with the diff, apply the changes:

```bash
chezmoi apply
```

By default, `chezmoi init --apply` and `chezmoi apply` on macOS/Linux do the following:

1. Install `fish` via Homebrew/Linuxbrew
2. Set Fish as the default login shell (when `CHEZMOI_DEFAULT_SHELL=fish`, which is the default)
3. Install these tools via Homebrew/Linuxbrew from a Fish execution context:

- `starship`
- `zoxide`
- `eza`
- `bat`
- `fzf`
- `direnv`
- `atuin`
- `fd`
- `ripgrep`
- `git`
- `gh`
- `jq`
- `poppler` (`pdfinfo`, `pdftotext`)
- `qpdf`
- `tesseract`
- `ocrmypdf`
- `pandoc`
- `git-delta`
- `procs`
- `bottom` (`btm`)
- `dust`
- `gping`

4. Install Fish plugins:

- `jorgebucaran/fisher`
- `PatrickF1/fzf.fish`
- `jethrokuan/z`
- `nickeb96/puffer-fish`

Installation is idempotent: already-installed formulas are skipped.

To choose a different default shell during install:

```bash
CHEZMOI_DEFAULT_SHELL=zsh chezmoi init --apply vgaonkar
```

To skip this default package install, run with:

```bash
CHEZMOI_INSTALL_TOOLS=false chezmoi apply
```

This only skips tool/plugin installation; Fish shell installation/default-shell behavior still follows `CHEZMOI_DEFAULT_SHELL`.

## Platform-Specific Notes

### WSL2
If you're using Windows Subsystem for Linux, use the Linux installation method. These dotfiles include logic to detect WSL and apply specific tweaks for clipboard sharing and interop.

### macOS
The installation will attempt to set various macOS defaults (like dock behavior and keyboard repeat rates). You may need to log out and back in for these to take full effect.

## Verification

To ensure everything is working correctly, run these commands:

- `chezmoi status`: Checks for any unapplied changes.
- `fish --version`: Confirms Fish is installed.
- `alias`: Lists available aliases to ensure your profile loaded.

## Troubleshooting

### Permissions Errors
If you encounter permission issues during `chezmoi apply`, ensure you have write access to your home directory. Do not run chezmoi with `sudo` as it will apply configurations to the root user instead of your personal account.

### Path Issues
If commands like `chezmoi` or `git` aren't found after installation, your PATH variable might not have updated in the current session. Close and reopen your terminal.

### Existing Configurations
If you have existing dotfiles, Chezmoi will prompt you to resolve conflicts. You can choose to overwrite, skip, or merge changes.

---

[Back to Table of Contents](00-table-of-contents.md) | [Next: Quick Start](01-quick-start.md)
