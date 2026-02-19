# bat

bat is a `cat` replacement with syntax highlighting and paging.

Upstream:
- https://github.com/sharkdp/bat

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` aliases `cat` to `bat` when installed
- Zsh: `home/dot_zshrc.tmpl` aliases `cat` to `bat` when installed
- Fish: `home/dot_config/fish/config.fish.tmpl` abbreviates `cat` to `bat`

Quickstart
```bash
command -v bat
bat --version
```

Core commands
```bash
bat README.md
bat -n ~/.bashrc
bat --paging=never file.txt
```

Recipe: fzf preview
```bash
fzf --preview 'bat --color=always --style=numbers --line-range=:200 {}'
```
