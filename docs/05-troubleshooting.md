# Common Issues and Fixes

If you encounter problems during installation or usage, check these common solutions.

## Chezmoi Not Found

If you get a `command not found: chezmoi` error after installation:

1. **Check PATH**: Ensure `~/.local/bin` (Linux/macOS) or `~/bin` is in your `$PATH`.
2. **Reload Shell**: Run `source ~/.config/fish/config.fish` or restart your terminal. If you use Zsh/Bash instead, run `source ~/.zshrc` or `source ~/.bashrc`.
3. **Reinstall**: If it's still missing, try running the bootstrap script again.

## Permission Denied Errors

Usually occurs when scripts try to write to directories owned by root.

- **Solution**: Avoid using `sudo` with `chezmoi apply`. The scripts are designed to work in your home directory. If a system package needs installing, the script will prompt for a password when calling `brew`, `apt`, or `dnf`.

## Shell Not Changing

If you selected Fish but your terminal still opens Bash/Zsh:

1. **Check Default Shell**: Run `echo $SHELL`.
2. **Manual Change**: Run `chsh -s $(which fish)`.
3. **Restart**: You must log out and back in for the default shell change to take effect.

## Tools Not in PATH

If tools like `zoxide` or `fzf` aren't working:

- **Verify Installation**: Check if the tool exists in your bin directory.
- **Check Fish config first**: Ensure `~/.config/fish/config.fish` is loading correctly (for example `zoxide init fish | source`).
- **If using Zsh/Bash**: Ensure the shell config is sourcing the tool's init script (for example `eval "$(zoxide init zsh)"`).

## Template Errors

If `chezmoi apply` fails with a template error:

- **Check Syntax**: Look for mismatched `{{` or `}}`.
- **Undefined Variables**: Ensure any variables you use are defined in `.chezmoidata.yaml` or are built-in Chezmoi variables.
- **Debug**: Run `chezmoi execute-template < filename.tmpl` to see the generated output and pinpoint the error.

## Git Push Issues

If you cannot push changes to your fork:

- **Authentication**: Ensure you have an SSH key configured and added to your GitHub account.
- **Remote URL**: Check that your origin points to your fork, not the upstream repository.
  ```bash
  git remote -v
  ```

## Platform-Specific Quirks

### WSL2
- **Interop**: If Windows commands aren't working, check your `/etc/wsl.conf` for interop settings.
- **Clock Drift**: If `apt` fails with certificate errors, run `sudo hwclock -s` to sync your system clock.
- **`yarn dev` prints the URL but no browser opens**: Check the two hookups —
  `echo $BROWSER` should print `~/.local/bin/winbrowser`, and `command -v xdg-open`
  should resolve to `~/.local/bin/xdg-open`, not `/usr/bin/xdg-open`. Test the
  launcher directly with `winbrowser https://example.com`. See
  [Platform-Specific](07-platform-specific.md#default-browser).
- **The browser opens but the page won't load**: That's a binding problem, not a
  browser one. The dev server is on `127.0.0.1` only — bind `0.0.0.0` instead
  (`vite --host`).

### macOS
- **XCode Tools**: Ensure they are installed: `xcode-select --install`.
- **Homebrew**: If `brew` is missing, the installation script should handle it, but you may need to add it to your PATH manually on Apple Silicon (M1/M2/M3) chips.

### Windows

- **A driver update installs forever and nags on every shutdown**: Windows Update
  shows a vendor driver (e.g. Canon `2.90.2.30`) as pending, the install fails every
  time, and Windows offers to "update and shut down" on every shutdown. The cause is
  normally an orphaned vendor driver package in the driver store — the update targets
  a device whose old package is stale, the install fails (usually `0x800f020b`), and
  the pending-reboot flag never clears.

  Run from an **elevated** PowerShell, from a **clone of this repo** — `windows/` is
  excluded from chezmoi, so these files are not deployed to your home directory:

  ```powershell
  # 1. Diagnose only — nothing is changed
  .\windows\scripts\fix-stuck-driver-update.ps1 -Vendor Canon

  # 2. Apply the fix
  .\windows\scripts\fix-stuck-driver-update.ps1 -Vendor Canon -Execute

  # 3. Reboot, then confirm the fix actually held
  .\windows\scripts\fix-stuck-driver-update.ps1 -Vendor Canon -Verify

  # 4. Install Canon's own driver, from Canon's site
  ```

  The script backs up every driver package it touches (and verifies the backup landed)
  before deleting anything. Backups, a `diagnosis.json` snapshot, and a transcript go to
  `%USERPROFILE%\dotfiles-backups\driver-fix\<timestamp>\`. `-Verify` diffs against that
  snapshot and exits non-zero if the flags did not clear or the packages are still
  present. Once verified, install the driver from the vendor's own site rather than
  Windows Update.

  **Order matters.** `-BlockByHardwareId` blocks *all* driver installs for that
  hardware — including Canon's own driver. Install the vendor driver first, then block:

  ```powershell
  .\windows\scripts\fix-stuck-driver-update.ps1 -Vendor Canon -Execute -SkipDriverPurge -SkipUpdateReset -BlockByHardwareId
  ```

  **Windows Home:** both blocking options write Group Policy keys that Microsoft
  documents for Pro, Enterprise, Education and IoT Enterprise only. On Home they are
  written and then silently ignored. The script warns when it detects a Home edition;
  rely on the purge plus a vendor-supplied driver there.

  Useful extras: `-DisableDriverUpdate` blocks *all* Windows Update drivers (blunter
  than `-BlockByHardwareId`); `-RepairImage` runs DISM + `sfc /scannow` when a
  reboot flag survives; `-SkipDriverPurge` / `-SkipUpdateReset` narrow a run;
  `Get-Help .\windows\scripts\fix-stuck-driver-update.ps1 -Full` documents every switch.
  Each `-Execute` run writes a `RESTORE.md` next to its backups with the exact commands
  to undo it.

## Where to Get Help

- **Check Logs**: Look at any error output in your terminal.
- **GitHub Issues**: Search the issues in this repository.
- **Chezmoi Docs**: Visit [chezmoi.io](https://www.chezmoi.io/) for detailed documentation on the tool itself.
