# ripgrep (rg)

ripgrep is a fast text search tool.

Upstream:
- https://github.com/BurntSushi/ripgrep

Wiring note
- Not wired by default in this repo. If you add aliases/abbreviations, document them in `home/dot_bashrc.tmpl`, `home/dot_zshrc.tmpl`, and/or `home/dot_config/fish/config.fish.tmpl`.

Quickstart
```bash
command -v rg
rg --version
```

Core usage
```bash
rg "TODO" .
rg -n "function" src
rg --hidden --glob '!**/.git/**' "needle" .
```
