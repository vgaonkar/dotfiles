# Development and Contributing

This document outlines how to contribute to this repository and the standards for development.

## Repository Structure

*   `dot_`: Files starting with `dot_` become hidden files (e.g., `dot_zshrc` becomes `.zshrc`).
*   `executable_`: Files starting with `executable_` will have the execute bit set.
*   `private_`: Files starting with `private_` will have restricted permissions (e.g., `0600`).
*   `.tmpl`: Files ending in `.tmpl` are processed as Go templates.
*   `docs/`: Documentation for the project.
*   `scripts/`: Automation for installation and maintenance.

## How to Test Changes

Before committing, verify your changes won't break your configuration.

1.  **Check the Diff:**
    ```bash
    chezmoi diff
    ```
2.  **Verify Templates:**
    ```bash
    # Test a specific template
    chezmoi execute-template < path/to/file.tmpl
    ```
3.  **Dry Run:**
    ```bash
    chezmoi apply --dry-run
    ```

## Adding New Templates

When adding a new configuration file:

1.  Add it to Chezmoi: `chezmoi add ~/.newconfig`
2.  If it needs variables, rename it: `chezmoi cd` and `mv dot_newconfig dot_newconfig.tmpl`
3.  Edit the file to add template logic.
4.  Test it with `chezmoi execute-template`.

## Adding Documentation

Documentation is stored in the `docs/` directory using Markdown.

*   Keep files numbered sequentially (e.g., `10-new-topic.md`).
*   Link to related documents at the bottom of each file.
*   Use clear headings and code blocks for examples.

## Testing on Multiple Platforms

If you're making changes to shared files (like `.zshrc`):

*   Verify it works on both macOS and Linux.
*   Use conditional logic `{{ if eq .chezmoi.os "darwin" }}` for platform-specific settings.
*   Avoid using tools that aren't available on all supported platforms unless you wrap them in an existence check.

## Submitting Changes

1.  Create a new branch: `git checkout -b feature/my-new-config`
2.  Commit your changes following the [Atomic Commits](https://www.conventionalcommits.org/) style.
3.  Push your branch: `git push -u origin feature/my-new-config`
4.  Open a Pull Request on GitHub.

---

[Back to Index](../README.md)
