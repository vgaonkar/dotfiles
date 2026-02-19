# puffer-fish (Fish plugin)

`puffer-fish` adds command-line expansions in Fish.

Upstream:
- https://github.com/nickeb96/puffer-fish

Notes
- Not wired by default in this repo.

If you wire it into these dotfiles
- Document the setup entrypoint in `home/dot_config/fish/config.fish.tmpl` (or a `conf.d` file managed by chezmoi).

Common expansions
```fish
cd ...
....
!!
!$
```
