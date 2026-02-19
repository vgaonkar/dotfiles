# gping

gping is `ping` with a graph.

Upstream:
- https://github.com/orf/gping

Wiring note
- Not wired by default in this repo. If you add aliases/abbreviations, document them in `home/dot_bashrc.tmpl`, `home/dot_zshrc.tmpl`, and/or `home/dot_config/fish/config.fish.tmpl`.

Quickstart
```bash
command -v gping
gping --version
```

Core usage
```bash
gping 8.8.8.8
gping github.com
gping 1.1.1.1 8.8.8.8
```
