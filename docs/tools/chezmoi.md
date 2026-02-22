# chezmoi

chezmoi manages dotfiles by keeping a "source state" (this repo) and applying it to your home directory.

Upstream:
- https://chezmoi.io/
- Quickstart: https://chezmoi.io/quick-start/
- Reference: https://chezmoi.io/reference/

Repo context
- Templates live under `home/`.
- Documentation index: `docs/00-table-of-contents.md`.

Core commands
```bash
chezmoi init --apply vgaonkar
chezmoi status
chezmoi diff
chezmoi apply
chezmoi edit ~/.config/fish/config.fish
chezmoi add ~/.myconfig
chezmoi update
```

Troubleshooting
- If a file isn't managed: `chezmoi managed ~/.somefile`
