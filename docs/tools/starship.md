# starship

Starship is a fast, cross-shell prompt.

Upstream:
- https://starship.rs/
- Guide: https://starship.rs/guide/
- Config reference: https://starship.rs/config/

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` initializes `starship init bash`
- Zsh: `home/dot_zshrc.tmpl` initializes `starship init zsh`
- Fish: `home/dot_config/fish/config.fish.tmpl` initializes `starship init fish | source`

Config in this repo:
- `home/dot_config/starship.toml`
Applied path:
- `~/.config/starship.toml`

Quickstart
```bash
command -v starship
starship --version
```

Inspect output
```bash
starship explain
starship module directory
starship module git_status
```

Troubleshooting
- If symbols/icons look wrong, install a Nerd Font and configure your terminal.
