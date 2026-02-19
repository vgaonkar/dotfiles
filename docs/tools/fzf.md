# fzf

fzf is a general-purpose fuzzy finder. You feed it a list, it returns your selection.

Upstream:
- https://github.com/junegunn/fzf
- Manual: https://github.com/junegunn/fzf/blob/master/doc/fzf.txt
- Examples: https://github.com/junegunn/fzf/wiki/Examples

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` uses `source <(fzf --bash)`
- Zsh: `home/dot_zshrc.tmpl` uses `source <(fzf --zsh)`
- Fish: `home/dot_config/fish/config.fish.tmpl` uses `fzf --fish | source`

Quickstart
```bash
command -v fzf
fzf --version
```

Core usage
```bash
ls | fzf
git branch --all | fzf
```

Useful options
```bash
fzf --height=40% --layout=reverse --border
fzf --multi
fzf --preview 'bat --color=always --style=numbers --line-range=:200 {}'
```

Recipes
```bash
cd "$(find . -type d 2>/dev/null | fzf)"
rg -n "TODO" . | fzf
git log --oneline --decorate | fzf
```

Customization
- `FZF_DEFAULT_OPTS`
- `FZF_DEFAULT_COMMAND`

Troubleshooting
- If keybindings do nothing, verify shell integration is loaded from your shell's init file.
