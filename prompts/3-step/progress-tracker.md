# RICECO Progress Tracker — dotfiles

> **CLAUDE:** Track active tasks, decisions, and outcomes here. Update after each working session.

---

## Compile Run

| Field | Value |
|-------|-------|
| Compiled | 2026-03-06 |
| Mode | `--compile` (context extracted from existing codebase) |
| Source files read | `.chezmoi.toml.tmpl`, `run_onchange_install_brew_tools.sh.tmpl`, `dot_config/fish/config.fish.tmpl`, `dot_zshrc.tmpl`, `README.md`, `CLAUDE.md` |
| Artifacts generated | step1-expert-anchor.md, step2-master-guide.md, step2-interview-context.md, step3-riceco-prompt.md, progress-tracker.md |

---

## Artifact Status

| Artifact | Status | Notes |
|----------|--------|-------|
| `step1-expert-anchor.md` | Done | Domain expert + decision heuristics |
| `step2-master-guide.md` | Done | Change classification, platform matrix, template vars, verification checklist, key file map |
| `step2-interview-context.md` | Done | Full project snapshot: tools, patterns, lifecycle, conventions |
| `step3-riceco-prompt.md` | Done | RICECO template with project-specific R/I/C/E/C/O + quick examples |
| `progress-tracker.md` | Done | This file |

---

## Active Tasks

_None — fresh compile, no in-flight work._

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-06 | Used `--compile` mode (no interactive interview) | Sufficient context in CLAUDE.md + source files to extract full project state |
| 2026-03-06 | Brew path always via template partial | Hardcoded paths break across macOS Intel/Apple Silicon and Linuxbrew |
| 2026-03-06 | `run_onchange_*` preferred over `run_once_*` for tool installs | Tool list changes must re-trigger install; `run_once_*` only runs once ever |

---

## Known Gaps / Future Updates

- [ ] Read `dot_bashrc.tmpl` and `dot_profile.tmpl` fully to complete bash/profile context
- [ ] Read `dot_config/git/config.tmpl` to document git config variables
- [ ] Read `windows/` directory to document PowerShell config scope
- [ ] Read `scripts/lint.sh` to document exact ShellCheck invocation
- [ ] Update `step2-interview-context.md` if new template variables are added to `.chezmoi.toml.tmpl`
- [ ] Re-run compile after any major structural change (new shell support, new secret management approach)

---

## Session History

| Date | Work Done | Outcome |
|------|-----------|---------|
| 2026-03-06 | Initial RICECO compile from codebase | All 5 artifacts created |
