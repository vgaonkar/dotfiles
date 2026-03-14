<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# screenshots

## Purpose
Terminal preview screenshots in SVG format, generated from VHS tape definitions. Used in documentation and the showcase site to demonstrate tool functionality.

## Key Files

| File | Description |
|------|-------------|
| `generate-svg.py` | Python script that generates SVG screenshots from VHS tape recordings |
| `prompt.svg` | Starship prompt preview |
| `eza.svg` | eza (modern ls) preview |
| `bat.svg` | bat (syntax-highlighted cat) preview |
| `fzf.svg` | fzf (fuzzy finder) preview |
| `atuin.svg` | Atuin (shell history) preview |
| `delta.svg` | delta (git diff) preview |
| `zoxide.svg` | zoxide (smart cd) preview |
| `README.md` | Description of screenshot generation process |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `tapes/` | VHS tape definitions that script terminal recordings |

## For AI Agents

### Working In This Directory

- SVG files are **generated output** -- edit the `.tape` files in `tapes/` or `generate-svg.py` to change screenshots.
- VHS tapes use the [VHS](https://github.com/charmbracelet/vhs) format: simple DSL for scripting terminal recordings.
- Do not manually edit SVG files; regenerate them instead.

### Testing Requirements

- Run `python3 generate-svg.py` to regenerate all SVGs
- Verify SVGs render correctly in a browser

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
