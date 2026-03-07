# Build System Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /home/dev/Projects/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 1 build tool (Chezmoi), 1 linter (ShellCheck), 1 PS linter config
**Critical issues:** None
**Key facts:**
- No traditional build system (no webpack, vite, tsc, make) -- Chezmoi IS the build system
- Chezmoi templates are "compiled" at apply-time via Go text/template engine
- ShellCheck is the only static analysis tool configured (severity=error)
- PSScriptAnalyzer settings exist but no PS lint script is wired up in CI

**Dependencies:** Chezmoi (template rendering), ShellCheck (linting), Go text/template (template engine)

---

## Critical Findings

1. **PSScriptAnalyzer config exists but is not used in CI.** `PSScriptAnalyzerSettings.psd1` is present but the CI workflow only runs ShellCheck on bash scripts. PowerShell scripts in `scripts/` and `windows/` are not linted.

2. **lint.sh only scans `scripts/` directory.** Template files (`*.tmpl`) containing bash are not linted because they contain Go template syntax that ShellCheck cannot parse. This is expected behavior but means shell syntax errors in templates are only caught at `chezmoi apply` time.

## Inventory

### Build Tools

| Tool | Role | Config File |
|------|------|-------------|
| Chezmoi | Template engine + file manager | `.chezmoi.toml.tmpl` |
| ShellCheck | Shell script linter | `.shellcheckrc` |
| PSScriptAnalyzer | PowerShell linter (config only) | `PSScriptAnalyzerSettings.psd1` |

### Build Process

The "build" is `chezmoi apply`, which:
1. Reads `.chezmoi.toml.tmpl` and resolves user data
2. Processes all `.tmpl` files through Go's `text/template` engine
3. Copies/creates target files in `$HOME` with correct permissions
4. Executes `run_once_*` and `run_onchange_*` scripts

### Linting Configuration

**ShellCheck (`.shellcheckrc`):**
```
severity=error
disable=SC1007
source-path=SCRIPTDIR
```

- Only errors fail the lint (info/style/warning suppressed)
- SC1007 disabled (assignment-or-comparison ambiguity)
- Source paths resolved relative to script directory

**PSScriptAnalyzer (`PSScriptAnalyzerSettings.psd1`):**
- Configured but not wired into CI or any script

## Configuration

### Template Engine Details

| Setting | Value |
|---------|-------|
| Engine | Go `text/template` |
| Delimiters | `{{ }}` (default) |
| Available functions | Chezmoi builtins (`promptStringOnce`, `promptBoolOnce`, `env`, `template`, `include`, `sha256sum`, `hasKey`, `quote`) |
| Data sources | `.chezmoi.toml.tmpl` (user prompts), `.chezmoidata/` (secrets/data), `.chezmoi.*` (system info) |

### Build Time

Chezmoi apply is near-instantaneous for template rendering (< 1 second for this repo). The `run_onchange_*` scripts can take minutes due to `brew install`.

### Output Size

This repo manages approximately 15 target files in `$HOME` and `~/.config/`. Total rendered output is under 50KB of config text.

## Dependencies

- ShellCheck depends on being installed (CI installs via `apt-get`)
- Chezmoi depends on Go runtime (bundled in binary)
- Template rendering depends on `.chezmoi.toml.tmpl` having been initialized

## Impact Assessment

| Change | Impact |
|--------|--------|
| ShellCheck version upgrade | May flag new errors if rules change |
| Chezmoi version upgrade | Template function API is stable; low risk |
| Adding new `.tmpl` file | Automatically picked up by Chezmoi |
| Changing `.shellcheckrc` severity | Could surface many warnings currently suppressed |

## Evidence

| Check | Result |
|-------|--------|
| ShellCheck lint | PASS -- 6 scripts, 0 errors |
| Template rendering | Verified via CI (`chezmoi init` + `chezmoi diff`) |
| Build reproducibility | Not guaranteed (no version pinning) |
| Multi-stage build | N/A (not a compiled project) |
| Environment-specific builds | Yes -- templates produce different output per OS/arch/user prefs |
