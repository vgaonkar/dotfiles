# Shell Tools & Plugins

This directory documents the CLI tools and shell enhancements used in this dotfiles setup.

Notes on terms used here:
- "Wired" means the dotfiles initialize the tool in shell startup files / configs.
- "Additional ecosystem tools" means related tools that are documented for reference.

## Recommended Learning Order

1. Navigation: `zoxide` + `eza`
2. Search + selection: `ripgrep` + `fd` + `fzf`
3. Per-project env: `direnv`
4. Prompt + history: `starship` + `atuin`
5. Diffs + dotfiles workflow: `delta` + `chezmoi`

## Inventory

### Wired By This Dotfiles Repo

Shell integration is implemented in:
- Bash: `home/dot_bashrc.tmpl`
- Zsh: `home/dot_zshrc.tmpl`
- Fish: `home/dot_config/fish/config.fish.tmpl`

Tool configs are implemented in:
- Starship: `home/dot_config/starship.toml`
- Atuin: `home/dot_config/atuin/config.toml`
- Git + delta: `home/dot_config/git/config.tmpl`

- [zoxide](zoxide.md) (upstream: https://github.com/ajeetdsouza/zoxide)
- [fzf](fzf.md) (upstream: https://github.com/junegunn/fzf)
- [direnv](direnv.md) (upstream: https://direnv.net/)
- [atuin](atuin.md) (upstream: https://docs.atuin.sh/)
- [starship](starship.md) (upstream: https://starship.rs/)
- [bat](bat.md) (upstream: https://github.com/sharkdp/bat)
- [eza](eza.md) (upstream: https://eza.rocks/)
- [delta](delta.md) (upstream: https://github.com/dandavison/delta)
- [chezmoi](chezmoi.md) (upstream: https://chezmoi.io/)

### Fish Add-ons Installed By Default

These are installed during default bootstrap:
- Fish plugin manager: [fisher](fisher.md) (upstream: https://github.com/jorgebucaran/fisher)
- Fish fzf bindings: [fzf.fish](fzf-fish.md) (upstream: https://github.com/PatrickF1/fzf.fish)
- Fish directory jumping: [z](z-fish.md) (upstream: https://github.com/jethrokuan/z)
- Fish text expansion: [puffer-fish](puffer-fish.md) (upstream: https://github.com/nickeb96/puffer-fish)

### Additional Ecosystem Tools (Docs Reference)

These are commonly used with the above tools.

- [fd](fd.md) (upstream: https://github.com/sharkdp/fd)
- [rg (ripgrep)](ripgrep.md) (upstream: https://github.com/BurntSushi/ripgrep)
- [procs](procs.md) (upstream: https://github.com/dalance/procs)
- [btm (bottom)](btm.md) (upstream: https://github.com/ClementTsang/bottom)
- [dust](dust.md) (upstream: https://github.com/bootandy/dust)
- [gping](gping.md) (upstream: https://github.com/orf/gping)

## Fish Keybindings Note (Important)

There are multiple ways to get fzf keybindings in Fish.

Start here:
- [fish-keybindings-and-fzf](fish-keybindings-and-fzf.md)

## Tool Doc Template

Copy this template for each `docs/tools/*.md` file.

### Title

What it is + when to use it.

Upstream:
- https://example.com

Wiring in this repo:
- `home/...` (template path)
- Result on disk after `chezmoi apply`: `~/.config/...` / `~/.zshrc` / etc.

Quickstart

```bash
command -v TOOL
TOOL --version
```

Core commands (5)

```bash
# ...
```

Recipes (5)

```bash
# ...
```

Customization
- Environment variables
- Config files (path + key options)

Troubleshooting
- How to verify wiring is active
- Common failure modes
