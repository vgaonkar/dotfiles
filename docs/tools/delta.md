# delta

delta is a syntax-highlighting pager for diffs (commonly used as a git pager).

Upstream:
- https://github.com/dandavison/delta

Wiring in this repo:
- Git config sets: `core.pager = delta`
- Source: `home/dot_config/git/config.tmpl`

Quickstart
```bash
command -v delta
delta --version
```

Core usage
```bash
git diff
git show
git diff | delta
```

Troubleshooting
- `git config --get core.pager` should print `delta`.
