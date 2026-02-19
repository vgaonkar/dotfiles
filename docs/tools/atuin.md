# atuin

Atuin replaces shell history with a searchable database (optionally syncable across machines).

Upstream:
- Docs: https://docs.atuin.sh/
- Config reference: https://docs.atuin.sh/configuration/config/

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` initializes `atuin init bash`
- Zsh: `home/dot_zshrc.tmpl` initializes `atuin init zsh`
- Fish: `home/dot_config/fish/config.fish.tmpl` initializes `atuin init fish | source`

Config in this repo:
- `home/dot_config/atuin/config.toml`
Applied path:
- `~/.config/atuin/config.toml`

Quickstart
```bash
command -v atuin
atuin --version
```

Core commands
```bash
atuin search
atuin stats
atuin sync
```

Troubleshooting
- If the default history filter feels too narrow, review `filter_mode` in the config.
