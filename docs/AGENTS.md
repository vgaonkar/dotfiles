<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# docs

## Purpose
User-facing documentation for the dotfiles project. Contains numbered guides (00-09) covering installation, configuration, troubleshooting, and platform-specific instructions, plus per-tool reference docs, audit reports, and architecture research.

## Key Files

| File | Description |
|------|-------------|
| `00-table-of-contents.md` | Master index of all documentation |
| `01-quick-start.md` | Getting started in under 5 minutes |
| `02-installation.md` | Detailed installation guide for all platforms |
| `03-configuration.md` | How to customize Chezmoi prompts and variables |
| `04-customization.md` | Adding new dotfiles and templates |
| `05-troubleshooting.md` | Common issues and fixes |
| `06-secrets-management.md` | Age encryption and `.chezmoidata/` usage |
| `07-platform-specific.md` | macOS, Linux, WSL2, and Windows differences |
| `08-migration-guide.md` | Migrating from other dotfile managers |
| `09-development.md` | Contributing and development workflow |
| `starship-themes-guide.md` | Starship prompt theme customization guide |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `tools/` | Per-tool reference guides for each installed CLI tool (see `tools/AGENTS.md`) |
| `audit/` | Deep-verify audit reports: file structure, CI/CD, security, dependencies (see `audit/AGENTS.md`) |
| `examples/` | Example configuration files (e.g., `secrets.yml.example`) |
| `research/` | Architecture research documents (Chezmoi cross-platform strategy) |

## For AI Agents

### Working In This Directory

- Documentation files use **sequential numbering** (00-09) for the main guides.
- Keep `00-table-of-contents.md` updated when adding new guides.
- Link related documents at the bottom of each file.
- Use clear headings, code blocks, and examples.
- The `research/` subdirectory contains one comprehensive research doc on Chezmoi architecture -- reference it, do not duplicate its content.

### Common Patterns

- Markdown with code fences for shell commands
- Cross-references between numbered docs
- Tool docs in `tools/` follow a consistent format: description, installation, usage, configuration

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
