# Fish Keybindings + fzf Integration

Upstream:
- fzf: https://github.com/junegunn/fzf
- fzf.fish plugin: https://github.com/PatrickF1/fzf.fish

Wiring in this repo:
- Fish base integration: `home/dot_config/fish/config.fish.tmpl` uses `fzf --fish | source`

Important context:
- Fish can have fzf keybindings from fzf itself (via `fzf --fish | source`) and/or from the community plugin `fzf.fish`.
- Enabling both can cause duplicate initialization and confusing keybinding behavior.

## Integration Options

### Option A: fzf built-in Fish integration (wired by this repo)

The dotfiles template enables:
- `fzf --fish | source`

This usually installs a small set of interactive keybindings and helper functions.

### Option B: `PatrickF1/fzf.fish` plugin (optional)

If you install `fzf.fish`, it typically configures bindings via `fzf_configure_bindings`.

## Default `fzf.fish` Keybindings (plugin)

These are the defaults used by `fzf.fish` when it calls `fzf_configure_bindings`:

| Feature | Binding | Command/Action |
| --- | --- | --- |
| Directory search | `Alt+Ctrl+F` | `_fzf_search_directory` |
| Git log search | `Alt+Ctrl+L` | `_fzf_search_git_log` |
| Git status search | `Alt+Ctrl+S` | `_fzf_search_git_status` |
| History search | `Ctrl+R` | `_fzf_search_history` |
| Process search | `Alt+Ctrl+P` | `_fzf_search_processes` |
| Variable search | `Ctrl+V` | `_fzf_search_variables ...` |

Implementation detail:
- Fish stores these bindings as escape/control sequences.

## Avoiding Duplicate/Conflicting Bindings

If you enable `fzf.fish` plugin bindings, consider disabling `fzf --fish | source` (or vice versa).

Symptoms of double-enabling:
- `Ctrl+R` behaves differently across sessions
- keybindings run the "wrong" picker
- keybindings disappear after loading order changes

## Customizing `fzf.fish` bindings (optional)

`fzf.fish` supports overriding bindings by calling:

```fish
fzf_configure_bindings --help
```

Example override (illustrative):

```fish
fzf_configure_bindings --history=\cf
```

## Quick checks

```fish
functions | string match -r '^fzf_configure_bindings$'
bind | string match -r '_fzf_search_'
```
