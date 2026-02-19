# fisher (Fish plugin manager)

fisher installs and updates Fish plugins.

Upstream:
- https://github.com/jorgebucaran/fisher

Wiring
- Not wired by default in this repo.
- If you decide to manage Fish plugins in this repo, document the wiring in `home/dot_config/fish/config.fish.tmpl`.

Quickstart
```fish
fisher --version
fisher list
```

Core commands
```fish
fisher install jorgebucaran/fisher
fisher install PatrickF1/fzf.fish
fisher update
```
