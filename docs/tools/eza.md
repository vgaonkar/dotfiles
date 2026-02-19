# eza

eza is a modern `ls` replacement.

Upstream:
- https://eza.rocks/
- https://github.com/eza-community/eza

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` aliases `ls`/`ll`/`la`/`l` to `eza ... --icons` when installed
- Zsh: `home/dot_zshrc.tmpl` aliases `ls`/`ll`/`la`/`l` to `eza ... --icons` when installed
- Fish: `home/dot_config/fish/config.fish.tmpl` abbreviates `ls`/`ll`/`la`/`l` to `eza ...`

Quickstart
```bash
command -v eza
eza --version
```

Core commands
```bash
eza
eza -al
eza --tree --level=2
eza --git -al
```

Troubleshooting
- Icons require a Nerd Font in your terminal.
