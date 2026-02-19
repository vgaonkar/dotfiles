# zoxide

zoxide is a smarter directory jumper that learns where you go and lets you jump there fast.

Upstream:
- https://github.com/ajeetdsouza/zoxide
- https://zoxide.rs/

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` (uses `eval "$(zoxide init bash)"`)
- Zsh: `home/dot_zshrc.tmpl` (uses `eval "$(zoxide init zsh)"`)
- Fish: `home/dot_config/fish/config.fish.tmpl` (uses `zoxide init fish | source`)

Quickstart
```bash
command -v zoxide
zoxide --version
```

Core commands
```bash
z foo
z foo bar
zoxide query foo
zoxide query -l | head
```

Interactive mode (pairs well with fzf)
```bash
zi
zoxide query -i
```

Customization
- Common env vars (see upstream docs): `_ZO_DATA_DIR`, `_ZO_EXCLUDE_DIRS`, `_ZO_FZF_OPTS`

Troubleshooting
- If `z`/`zi` are missing, verify the init line is being executed for your shell.
