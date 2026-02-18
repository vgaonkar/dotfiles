# Dotfiles

> 🏠 A portable, cross-platform dotfiles setup using Chezmoi

[![macOS](https://img.shields.io/badge/macOS-000000?style=flat&logo=apple&logoColor=white)](docs/07-platform-specific.md#macos)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)](docs/07-platform-specific.md#linux)
[![Windows](https://img.shields.io/badge/Windows-0078D6?style=flat&logo=windows&logoColor=white)](docs/07-platform-specific.md#windows)
[![WSL2](https://img.shields.io/badge/WSL2-0D9B68?style=flat&logo=windows-terminal&logoColor=white)](docs/07-platform-specific.md#wsl2)

One-command setup for a consistent development environment across all your machines.

---

## 🚀 Quick Start

Get up and running in under 5 minutes:

### macOS / Linux

```bash
sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply vgaonkar
```

### Windows (PowerShell)

```powershell
# Install chezmoi and apply dotfiles
irm get.chezmoi.io | iex; chezmoi init --apply vgaonkar
```

That's it! The installer will:
- ✅ Detect your OS and architecture
- ✅ Prompt you for preferences (default shell, work/personal mode)
- ✅ Install all necessary tools
- ✅ Configure your shells
- ✅ Set everything up automatically

---

## 📚 Documentation

Navigate our comprehensive documentation:

### Getting Started
| Document | Description | Read Time |
|----------|-------------|-----------|
| [📖 Table of Contents](docs/00-table-of-contents.md) | Master navigation for all docs | 1 min |
| [🚀 Quick Start](docs/01-quick-start.md) | Get running in 5 minutes | 5 min |
| [💻 Installation](docs/02-installation.md) | Detailed platform-specific install | 15 min |

### Understanding & Customizing
| Document | Description | Read Time |
|----------|-------------|-----------|
| [⚙️ Configuration](docs/03-configuration.md) | How the template system works | 10 min |
| [🎨 Customization](docs/04-customization.md) | Personalize your setup | 10 min |
| [🔐 Secrets Management](docs/06-secrets-management.md) | Handling sensitive data | 8 min |

### Reference & Help
| Document | Description | Read Time |
|----------|-------------|-----------|
| [🍎 Platform Specific](docs/07-platform-specific.md) | macOS/Linux/Windows quirks | 10 min |
| [🐛 Troubleshooting](docs/05-troubleshooting.md) | Common issues & fixes | 10 min |
| [🔄 Migration Guide](docs/08-migration-guide.md) | Moving from other tools | 8 min |
| [👨‍💻 Development](docs/09-development.md) | Contributing to this repo | 5 min |

---

## ✨ What's Included

### Shells
- **Fish** 🐟 - Friendly Interactive Shell (recommended default)
- **Zsh** 🧟 - Z Shell with modern configuration
- **Bash** 🅱️ - Bourne Again Shell (fallback)
- **PowerShell** 💻 - Windows PowerShell support

### Modern CLI Tools
| Tool | Purpose | Replaces |
|------|---------|----------|
| [Starship](https://starship.rs/) | Cross-shell prompt | Powerlevel10k, custom PS1 |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Smart directory jumping | `cd`, `autojump` |
| [Eza](https://github.com/eza-community/eza) | Modern file listing | `ls` |
| [Bat](https://github.com/sharkdp/bat) | Syntax-highlighted file viewer | `cat` |
| [FZF](https://github.com/junegunn/fzf) | Fuzzy finder | Ctrl+R history |
| [Direnv](https://direnv.net/) | Per-directory environments | Manual exports |
| [Atuin](https://atuin.sh/) | Better shell history | Native history |

### Features
- 🎯 **Interactive Setup** - Prompts for your preferences
- 🔄 **Cross-Platform** - Works on macOS, Linux, Windows, WSL2
- 📦 **One-Command Install** - Single command sets up everything
- 🔒 **Secrets Management** - Secure handling of API keys and tokens
- 🧪 **Tested** - Verified on multiple platforms

---

## 🏗️ Repository Structure

```
dotfiles/
├── 📄 README.md                 # This file
├── 📁 docs/                     # Documentation
├── 📁 home/                     # Unix dotfiles (templates)
│   ├── dot_bashrc.tmpl
│   ├── dot_zshrc.tmpl
│   └── dot_config/
│       ├── fish/config.fish.tmpl
│       ├── starship.toml
│       └── ...
├── 📁 windows/                  # Windows-specific configs
├── 📁 .chezmoidata/             # Data & secrets (gitignored)
├── 📁 .chezmoitemplates/        # Shared templates
└── 📁 scripts/                  # Helper scripts
```

---

## 🎬 Usage Examples

### Daily Use

```bash
# Add a new file to dotfiles
chezmoi add ~/.myconfig
chezmoi git add .
chezmoi git commit -m "Add myconfig"
chezmoi git push

# Edit a managed file
chezmoi edit ~/.zshrc

# See what would change
chezmoi diff

# Apply changes
chezmoi apply

# Pull updates from GitHub
chezmoi update
```

### On a New Machine

```bash
# One command installs everything
sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply vgaonkar

# You'll be prompted for:
# - Default shell (fish/zsh/bash)
# - Work or personal machine
# - Whether to install optional tools
```

---

## 🔧 Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Apple Silicon) | ✅ Fully Supported | M1/M2/M3 Macs |
| macOS (Intel) | ✅ Fully Supported | Older Macs |
| Ubuntu/Debian | ✅ Fully Supported | APT + Homebrew |
| Fedora/RHEL | ✅ Fully Supported | DNF + Homebrew |
| Arch Linux | ✅ Fully Supported | Pacman + Homebrew |
| Windows (WSL2) | ✅ Fully Supported | Ubuntu in WSL2 |
| Windows (Native) | ⚠️ Partial | PowerShell + Scoop |

---

## 🆘 Need Help?

- 🔍 Check [Troubleshooting](docs/05-troubleshooting.md)
- 📖 Read the [full documentation](docs/00-table-of-contents.md)
- 🐛 [Open an issue](../../issues) on GitHub
- 💬 [Discussions](../../discussions) for questions

---

## 🤝 Contributing

Contributions are welcome! See [Development Guide](docs/09-development.md) for details.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Chezmoi](https://www.chezmoi.io/) - The dotfiles manager that makes this possible
- [Starship](https://starship.rs/) - The cross-shell prompt
- All the amazing open-source tools included in this setup

---

<div align="center">

**[⬆ Back to Top](#dotfiles)**

Made with ❤️ for consistent development environments everywhere

</div>
