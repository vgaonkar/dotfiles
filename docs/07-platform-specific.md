# Platform Specific Notes

These dotfiles are designed to be cross-platform, supporting macOS, various Linux distributions, and Windows (via WSL2).

## macOS Setup

macOS requires a few extra steps for the best experience.

### Homebrew

Homebrew is the primary package manager. Ensure it's installed and the binary is in your PATH. On Apple Silicon, this is usually `/opt/homebrew/bin/brew`.

During `chezmoi init --apply`/`chezmoi apply`, the default bootstrap:
- installs `fish` with Homebrew,
- sets Fish as the default login shell (unless overridden),
- then installs this formula set via Fish:

- `starship`
- `zoxide`
- `eza`
- `bat`
- `fzf`
- `direnv`
- `atuin`
- `fd`
- `git`
- `gh`
- `jq`
- `poppler` (`pdfinfo`, `pdftotext`)
- `ripgrep`
- `qpdf`
- `tesseract`
- `ocrmypdf`
- `pandoc`
- `git-delta`
- `procs`
- `bottom` (`btm`)
- `dust`
- `gping`

It also installs Fish plugins:

- `jorgebucaran/fisher`
- `PatrickF1/fzf.fish`
- `jethrokuan/z`
- `nickeb96/puffer-fish`

### Xcode Command Line Tools

Many tools depend on these. Install them by running:

```bash
xcode-select --install
```

### Path Differences

Note that macOS uses `/Users/` while Linux uses `/home/`. Use the `{{ .chezmoi.homeDir }}` template variable to keep paths portable.

## Linux Setup

Linux uses Linuxbrew/Homebrew for the default tool bootstrap (same shell/tool flow as macOS): fish first, then the formula set.

### Linuxbrew

Install Linuxbrew/Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

If you use a non-standard distribution, install Linuxbrew manually and ensure `brew` is on your `PATH`.

## Windows / WSL2

Windows support is handled through WSL2 (Windows Subsystem for Linux).

### PowerShell

While these dotfiles focus on Linux-like environments, basic PowerShell profiles are included.

### Default Browser

Dev servers (`yarn dev`, Vite, CRA, Storybook) try to open a browser on start.
Inside WSL2 there is nothing for them to open, so the step silently no-ops.

These dotfiles ship `~/.local/bin/winbrowser`, which passes the URL to Windows
via `Start-Process`. That goes through the Windows shell's protocol
association, so it always uses your **current** Windows default browser rather
than a hardcoded path to Chrome or Edge.

Two hookups, because tools split on which one they honor:

- `$BROWSER` is set to the script in `config.fish.tmpl` (Vite, CRA, Storybook,
  and anything else using the `open` npm package read this).
- `~/.local/bin/xdg-open` is a symlink to it, covering tools that call
  `xdg-open` directly. `~/.local/bin` is prepended to `PATH` by fish, `.profile`
  (which zsh login shells source via `.zprofile`), and `.bashrc`, so the shim
  wins over `/usr/bin/xdg-open`.

The script guards itself: on a non-WSL Linux box it `exec`s the real
`/usr/bin/xdg-open`, so shadowing that name is safe. `.chezmoiignore` also
keeps both files off macOS and Windows entirely.

The conventional alternative is `wslu`, which provides `wslview`. It is not
available through Homebrew — it ships via apt/dnf/pacman only — so it needs
root, which is often unavailable on a work machine. Hence the in-repo script.
If you do have root and prefer the package: `sudo apt install wslu`, then set
`BROWSER` to `wslview` (it installs its own `xdg-open` too).

### WSL Config

Ensure your `.wslconfig` in Windows is set up to handle memory and CPU limits effectively. You can manage this file through Chezmoi if you run it from the Windows side, but it's usually easier to keep it separate.

## Path Handling

Always use forward slashes `/` in templates. Chezmoi handles the conversion on Windows where necessary. Use the following logic to handle platform-specific snippets:

```bash
{{ if eq .chezmoi.os "darwin" }}
# macOS specific config
{{ else if eq .chezmoi.os "linux" }}
# Linux specific config
{{ end }}
```

## Known Issues and Workarounds

*   **Clipboard:** On WSL2, you may need `win32yank.exe` to share the clipboard with Windows.
*   **Fonts:** Nerd Fonts must be installed on the host OS (macOS or Windows) for terminal icons to render correctly in SSH or WSL.

## Testing on Each Platform

Before pushing changes that affect multiple systems, verify them:

1.  Run `chezmoi execute-template` to see how the file renders on that OS.
2.  Use a VM or Docker container for Linux testing if you are on macOS.

---

[Next: Migration Guide](08-migration-guide.md)
