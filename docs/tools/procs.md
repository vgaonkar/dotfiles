# procs

procs is a modern replacement for `ps`.

Upstream:
- https://github.com/dalance/procs

Wiring note
- Not wired by default in this repo. If you add aliases/abbreviations, document them in `home/dot_bashrc.tmpl`, `home/dot_zshrc.tmpl`, and/or `home/dot_config/fish/config.fish.tmpl`.

Quickstart
```bash
command -v procs
procs --version
```

Core usage
```bash
procs
procs --tree
procs --watch
```
