# Installation Guide

This document provides a detailed walkthrough for installing and verifying your new development environment.

## Prerequisites

Before running the installation, ensure your system meets these basic requirements.

### macOS
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew (recommended): `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Linux (Ubuntu/Debian)
- Git: `sudo apt update && sudo apt install git`
- Curl: `sudo apt install curl`

### Windows
- Git for Windows
- PowerShell 7 (highly recommended)
- Windows Terminal


### GitHub Authentication (SSH)

GitHub no longer supports password authentication for Git operations. You must use SSH or a Personal Access Token.

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

## Platform-Specific Notes

### WSL2
If you're using Windows Subsystem for Linux, use the Linux installation method. These dotfiles include logic to detect WSL and apply specific tweaks for clipboard sharing and interop.

### macOS
The installation will attempt to set various macOS defaults (like dock behavior and keyboard repeat rates). You may need to log out and back in for these to take full effect.

## Verification

To ensure everything is working correctly, run these commands:

- `chezmoi status`: Checks for any unapplied changes.
- `zsh --version`: Confirms Zsh is installed.
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
