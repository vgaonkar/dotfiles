# Common Issues and Fixes

If you encounter problems during installation or usage, check these common solutions.

## Chezmoi Not Found

If you get a `command not found: chezmoi` error after installation:

1. **Check PATH**: Ensure `~/.local/bin` (Linux/macOS) or `~/bin` is in your `$PATH`.
2. **Reload Shell**: Run `source ~/.zshrc` or restart your terminal.
3. **Reinstall**: If it's still missing, try running the bootstrap script again.

## Permission Denied Errors

Usually occurs when scripts try to write to directories owned by root.

- **Solution**: Avoid using `sudo` with `chezmoi apply`. The scripts are designed to work in your home directory. If a system package needs installing, the script will prompt for a password when calling `brew`, `apt`, or `dnf`.

## Shell Not Changing

If you installed Zsh but your terminal still opens Bash:

1. **Check Default Shell**: Run `echo $SHELL`.
2. **Manual Change**: Run `chsh -s $(which zsh)`.
3. **Restart**: You must log out and back in for the default shell change to take effect.

## Tools Not in PATH

If tools like `zoxide` or `fzf` aren't working:

- **Verify Installation**: Check if the tool exists in your bin directory.
- **Check `.zshrc`**: Ensure the shell configuration is correctly sourcing the tool's init script. Look for lines like `eval "$(zoxide init zsh)"`.

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

### macOS
- **XCode Tools**: Ensure they are installed: `xcode-select --install`.
- **Homebrew**: If `brew` is missing, the installation script should handle it, but you may need to add it to your PATH manually on Apple Silicon (M1/M2/M3) chips.

## Where to Get Help

- **Check Logs**: Look at any error output in your terminal.
- **GitHub Issues**: Search the issues in this repository.
- **Chezmoi Docs**: Visit [chezmoi.io](https://www.chezmoi.io/) for detailed documentation on the tool itself.
