<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# mise

## Purpose
Configuration for [mise](https://mise.jdx.dev/) (formerly rtx), a polyglot runtime version manager. Manages tool versions for Node.js, Python, Ruby, and other languages.

## Key Files

| File | Description |
|------|-------------|
| `config.toml` | Global mise settings (static, not templated) |

## For AI Agents

### Working In This Directory

- Static TOML config -- no template processing needed.
- This is the **global** mise config (`~/.config/mise/config.toml`). Project-level `.mise.toml` files override these settings.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
