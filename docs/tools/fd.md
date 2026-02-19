# fd

fd is a simpler, faster alternative to `find`.

Upstream:
- https://github.com/sharkdp/fd

Wiring note
- Not wired by default in this repo. If you add aliases/abbreviations, document them in `home/dot_bashrc.tmpl`, `home/dot_zshrc.tmpl`, and/or `home/dot_config/fish/config.fish.tmpl`.

Quickstart
```bash
command -v fd
fd --version
```

Core usage
```bash
fd package.json
fd -t f "\.md$"
fd -e ts
```
