# Migration Guide

Moving your existing dotfiles configuration to this repository is straightforward. This guide covers the transition from common management methods.

## From Bare Git Repo

If you currently use a bare Git repository (e.g., `git --git-dir=$HOME/.cfg/ --work-tree=$HOME`):

1.  Identify the files you want to keep.
2.  Add them to Chezmoi: `chezmoi add ~/path/to/file`
3.  Chezmoi will copy them into its source directory (usually `~/.local/share/chezmoi`).
4.  Remove the old `.cfg` directory once you've verified everything is imported.

## From GNU Stow

GNU Stow uses symlinks to manage files.

1.  Go to your Stow directory.
2.  Import each package: `chezmoi add ~/.bashrc` (repeat for all linked files).
3.  Chezmoi will take the target of the symlink and store the actual file content.
4.  Unstow your files: `stow -D package_name`
5.  Apply with Chezmoi: `chezmoi apply`

## From YADM

YADM is very similar to a bare Git repo but with extra features.

1.  Use `yadm list` to see tracked files.
2.  Add them to Chezmoi one by one or in bulk.
3.  Note that YADM templates are not compatible with Chezmoi templates. You'll need to rewrite logic using Go template syntax.

## Importing Existing Configs

If you have untracked files you'd like to include:

```bash
# Add a single file
chezmoi add ~/.zshrc

# Add a directory
chezmoi add ~/.config/nvim
```

## Tips for a Smooth Transition

*   **Start Small:** Don't move everything at once. Start with your shell config (`.zshrc` or `.bashrc`) and editor config.
*   **Use `diff`:** Before applying, always run `chezmoi diff` to see what will change.
*   **Check Templates:** If a file contains machine-specific paths, rename it to add `.tmpl` and use variables like `{{ .chezmoi.homeDir }}`.
*   **Keep Backups:** Don't delete your old setup until you've successfully run `chezmoi apply` and verified your environment works.

---

[Next: Development and Contributing](09-development.md)
