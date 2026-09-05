# Apply checklist — Windows default browser from WSL2

**Status:** Implemented in this repo, **unverified on hardware.** Everything
below still needs to run on the WSL work machine.
**Implemented:** 2026-09-04 (macOS, where none of it is executable)

Reference documentation now lives in
[`07-platform-specific.md` → Default Browser](../07-platform-specific.md#default-browser)
and [`05-troubleshooting.md` → WSL2](../05-troubleshooting.md#wsl2).
**Delete this file once the checklist below passes.**

## What shipped

| File | Change |
|---|---|
| `dot_local/bin/executable_winbrowser` | New. Hands a URL/file to Windows via `Start-Process`. Self-guards: outside WSL it `exec`s the real `/usr/bin/xdg-open`. |
| `dot_local/bin/symlink_xdg-open` | New. One line, `winbrowser` → deploys as `~/.local/bin/xdg-open -> winbrowser`. |
| `dot_config/fish/config.fish.tmpl` | Sets `BROWSER` under a `linux` template gate + a `/proc/version` runtime check. |
| `.chezmoiignore` | Template-gated `.local` ignore so nothing deploys on macOS/Windows. |
| `docs/05-*`, `docs/07-*` | User-facing docs. |

Design rationale (why a script rather than `wslu`, and why both `$BROWSER` and
the `xdg-open` shim) is in `07-platform-specific.md` — not repeated here.

## Verified on macOS

- `shellcheck -s sh` on `winbrowser` — clean. `scripts/lint.sh` — 12 scripts, passed.
- `chezmoi managed | grep '^\.local'` — empty. The ignore covers the parent
  directory too, so no empty `~/.local` is created off-WSL.
- `chezmoi execute-template < dot_config/fish/config.fish.tmpl` — no `wsl`,
  `browser`, or `microsoft` anywhere in the rendered macOS config.
- chezmoi mechanics confirmed against the reference docs, not assumed:
  `.chezmoiignore` is template-interpreted and matches **target** paths;
  `symlink_` takes the link target from the file body with the trailing
  newline stripped.

## Run on the WSL box

1. `chezmoi update` (or `git pull` in the source dir + `chezmoi apply`).
2. `chezmoi diff` — expect exactly two new files under `.local/bin/` plus the
   fish config hunk.
3. `exec fish`, then `echo $BROWSER` → `/home/<user>/.local/bin/winbrowser`.
4. `winbrowser https://example.com` → Windows default browser opens the page.
5. `command -v xdg-open` → the `~/.local/bin` one, **not** `/usr/bin/xdg-open`.
   Also check `bash -lc 'command -v xdg-open'` and `zsh -lc 'command -v xdg-open'`.
6. `xdg-open https://example.com` → same result as step 4.
7. Real test: `yarn dev` in a Vite/CRA project → browser opens on the dev URL.

PATH precedence for step 5 was traced in the templates and should hold: fish
prepends at `config.fish.tmpl:4`, bash at `dot_bashrc.tmpl:12`, and zsh login
shells inherit it because `dot_zprofile.tmpl` sources `~/.profile`, which
prepends at `dot_profile.tmpl:10`. Traced, not executed — hence step 5.

## Known limitations

- **Non-login zsh** never sources `.zprofile`, so the `xdg-open` shim may lose
  to `/usr/bin/xdg-open` there. `$BROWSER` still works, so this only bites a
  tool that both ignores `$BROWSER` and runs under a non-login zsh.
- **Path-vs-URL ambiguity.** `[ -e "$target" ]` means an argument naming an
  existing local file is treated as a file and converted with `wslpath`.
- **Trust boundary.** The argument is interpolated into a PowerShell command
  string. Single quotes are doubled to escape, but this is still a
  WSL→Windows process hop — feed it URLs from tools you are running yourself.
- **No `wslview` alias.** If some tool calls `wslview` by name, add a
  `symlink_wslview` next to the `xdg-open` one.
- **Page won't load after opening** is a binding problem, not a launcher one:
  bind `0.0.0.0` (`vite --host`) instead of `127.0.0.1`.

## Rollback

`git revert` the commit, `chezmoi apply`, then remove the two now-unmanaged
files by hand — `rm ~/.local/bin/winbrowser ~/.local/bin/xdg-open`. Deleting an
entry from the source state does not delete the deployed target; `chezmoi apply`
has no `--remove` flag (verified). Use `chezmoi destroy <target>` if you want
chezmoi to delete source, target, and state in one step.
