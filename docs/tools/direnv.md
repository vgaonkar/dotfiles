# direnv

direnv loads/unloads environment variables automatically when you enter/leave a directory.

Upstream:
- https://direnv.net/
- Hook docs: https://direnv.net/docs/hook.html
- stdlib docs: https://direnv.net/man/direnv-stdlib.1.html

Wiring in this repo:
- Bash: `home/dot_bashrc.tmpl` uses `eval "$(direnv hook bash)"`
- Zsh: `home/dot_zshrc.tmpl` uses `eval "$(direnv hook zsh)"`
- Fish: `home/dot_config/fish/config.fish.tmpl` uses `direnv hook fish | source`

Quickstart
```bash
command -v direnv
direnv --version
```

Basic workflow
```bash
cd /path/to/project
echo 'export FOO=bar' > .envrc
direnv allow
```

Common patterns
```bash
source_env_if_exists .envrc.local
layout node
```

Security model
- `.envrc` is shell code; `direnv allow` is required after changes.

Troubleshooting
- `direnv status`
- `direnv reload`
