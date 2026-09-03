# Audit — 9 Function Renames (`scripts/bootstrap/install.ps1`) + `scripts/lint.ps1` Repairs

> Read-only audit against `docs/audit/ps-lint-and-driver-fix/SPEC.md` Change 3 (R1-R4)
> and Change 4 (L1-L4). Toolchain: pwsh 7.6.5 + PSScriptAnalyzer, macOS arm64. No
> Windows PowerShell 5.1 runtime available on this host — anything gated on that is
> marked ASSUMED, never VERIFIED, per SPEC's own rule.

## Overall verdict: CONFIRMED CLEAN

No defects found in either Part A (renames) or Part B (lint.ps1). One LOW-severity
readability note and one PS-5.1-compatibility item that is ASSUMED-safe with strong
supporting evidence but not directly testable on this host.

---

## Part A — 9 function renames in `scripts/bootstrap/install.ps1`

### 1. Stale reference sweep (R1) — CONFIRMED CLEAN

Repo-wide `grep -rn "\b<name>\b"` for all 9 old identifiers (`To-Bool`,
`Ensure-EnvDefault`, `Ensure-Chezmoi`, `Ensure-Gh`, `Ensure-GhAuth`,
`Refresh-PathForGh`, `Maybe-SetupGit`, `Run-Chezmoi`, `Add-ToPathIfExeExists`),
excluding `.git`, across the entire tree (docs/, README.md, site/, scripts/*.sh,
.github/, dot_* files, *.tmpl):

- **Zero hits** in any executable/doc/template file.
- The only hits at all are in `docs/audit/ps-lint-and-driver-fix/SPEC.md` itself,
  where the old names appear intentionally as the "Old" column of the rename
  table and in invariant R2's text — this is the audit spec describing the
  rename, not a stale reference. Expected and correct.

No `.github/` workflows, no CI config referencing PowerShell function names, and no
shell scripts call into these functions by name (they're PowerShell-internal, not
exposed as CLI entry points), so there was no additional surface for staleness.

### 2. Clipping check — `Ensure-Gh` -> `Install-Gh` vs `Ensure-GhAuth` (R2) — CONFIRMED CLEAN

`grep -n "^function " scripts/bootstrap/install.ps1` shows both target functions
present, distinct, and correctly named:

```
171:function Install-Gh {
219:function Initialize-GhAuth([string]$Hostname, [bool]$Headless, [bool]$NonInteractive) {
```

No `Install-GhAuth` was accidentally created, and `Initialize-GhAuth` was not
mangled into anything else. The full function list (17 functions, including two
untouched pre-existing helpers `Install-GhWithWinget` / `Install-GhWithScoop`,
which have similar prefixes but are not part of the rename set and were unaffected)
shows no naming collisions from the substitution:

```
Write-Status, Write-Header, Write-Info, Write-Ok, Write-Warn, Write-Err,
ConvertTo-Boolean, Initialize-EnvDefault, Install-Chezmoi, Install-GhWithWinget,
Install-GhWithScoop, Add-ExeDirectoryToPath, Update-PathForGh, Install-Gh,
Test-GhAuth, Initialize-GhAuth, Initialize-GitIntegration, Invoke-Chezmoi
```

The commit message for `b7cec8d` explicitly states a longest-name-first
substitution order was used to avoid this exact failure mode; the evidence
confirms it worked.

### 3. Semantic equivalence (R3) — CONFIRMED CLEAN, with one caveat

`git diff b7cec8d~1:scripts/bootstrap/install.ps1` against the current file (full
unified diff reviewed line-by-line) shows the change set is **exactly**:

- (a) The 9 identifier renames from the table, at both definition and every call
  site (`Ensure-EnvDefault` calls at the 3 `$Dotfiles*` assignments,
  `Ensure-Chezmoi`/`Ensure-Gh`/`Ensure-GhAuth`/`Maybe-SetupGit`/`Run-Chezmoi` at
  the bottom of the script, `Refresh-PathForGh` inside `Ensure-Gh`'s body,
  `Add-ToPathIfExeExists` inside `Refresh-PathForGh`'s body, `To-Bool` inside the
  `Maybe-SetupGit`/`Initialize-GitIntegration` call).
- (b) The `Write-Host` -> `Write-Status` conversion (5 wrapper functions
  `Write-Header/Info/Ok/Warn/Err` now delegate to a new `Write-Status` helper,
  plus one direct `Write-Host $errText` -> `Write-Status $errText` inside
  `Run-Chezmoi`/`Invoke-Chezmoi`).
- (c) The empty-catch fix in the PATH-discovery loop inside
  `Refresh-PathForGh`/`Update-PathForGh`: `catch { # best-effort; ignore }`
  became `catch { Write-Verbose "Skipping PATH candidate '$dir': $($_.Exception.Message)" }`.

No other change of any kind — no whitespace-only edits, no string content
changes, no control-flow changes, no reordering — appears anywhere else in the
file. The diff is exhaustive (full `diff -u` reviewed, not sampled).

**Caveat (not a defect, a scope note):** categories (b) and (c) are technically
outside the literal "identifier rename" scope of Change 3's invariant table, but
they are explicitly called out as in-scope by SPEC's own R3 wording ("an
identifier rename from the table, (b) the Write-Host->Write-Status conversion,
(c) the empty-catch fix") — so this is fully compliant, not a gap. Flagging only
so the reader knows the diff isn't *purely* mechanical renames.

### 4. Call-site arity — CONFIRMED CLEAN

Every renamed function's call site(s) preserve identical parameter-passing
style pre- and post-rename:

| Call site | Style preserved |
|---|---|
| `Initialize-EnvDefault -Name "..." -DefaultValue "..."` (x3) | named params, unchanged |
| `Install-Chezmoi` | no-arg, unchanged |
| `Install-Gh` | no-arg, unchanged |
| `Initialize-GhAuth -Hostname $DotfilesGithubHost -Headless:$headless -NonInteractive:$nonInteractive` | named + switch-colon syntax, unchanged |
| `Initialize-GitIntegration -Hostname $DotfilesGithubHost -Skip:(ConvertTo-Boolean $DotfilesNoGhSetupGit)` | named + switch-colon + nested call, unchanged |
| `Invoke-Chezmoi` | no-arg, unchanged |
| `Add-ExeDirectoryToPath -Dir $dir -ExeName "gh.exe"` (inside `Update-PathForGh`) | named params, unchanged |
| `Update-PathForGh` (inside `Install-Gh`) | no-arg, unchanged |
| `ConvertTo-Boolean $DotfilesNoGhSetupGit` (positional, inside the `-Skip:(...)` call) | positional, unchanged |

No arity, positional/named style, or splatting changed for any call site.

### 5. Naming sanity — LOW severity, readability judgement calls only

- `Initialize-GitIntegration` for what was `Maybe-SetupGit`: the function still
  has an internal early-return skip path (`if ($Skip) { ...; return }`), and the
  new name doesn't signal that a call can be a no-op. This is arguably a mild
  readability regression vs. the old (unapproved-verb) `Maybe-` prefix, which at
  least communicated conditionality in plain English. Not a defect — `Initialize-`
  is an approved verb and the parameter name `-Skip` makes the conditionality
  visible at the call site (`-Skip:(ConvertTo-Boolean $DotfilesNoGhSetupGit)`),
  so the information isn't lost, just moved from the function name to the call
  site. LOW.
- `Install-Chezmoi` / `Install-Gh`: both return early with `Write-Ok "... already
  installed"` when the tool is already present. "Install" is still accurate as a
  description of intent/effect (idempotent installer), matching common PowerShell
  convention (e.g., `Install-Module` is also idempotent-early-return in practice).
  Not misleading enough to flag as a defect. LOW / non-issue.

### 6. PS 5.1 compatibility (R4)

The file declares `#Requires -Version 5.1` and is intended to run via Windows
PowerShell 5.1 on a fresh Windows machine (no pwsh 7 preinstalled). Reviewed every
construct touched by this change set:

- **`[string]::IsNullOrEmpty($Color)`** — static .NET method, available in every
  PowerShell version since 1.0 (it's a CLR method call, not a cmdlet). VERIFIED
  safe by inspection; no version gate applies to static .NET member access.
- **`Write-Verbose` inside a `catch` block** — `Write-Verbose` is a core cmdlet
  present since PowerShell 1.0; there is nothing catch-block-specific about it
  (it's an ordinary cmdlet call). VERIFIED safe by inspection.
- **`$Host.UI.WriteLine($Message)` / `$Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)`**
  — `PSHostUserInterface.WriteLine` and its 3 overloads (no-arg-color,
  fg-only... actually the 2-color overload used here) are part of
  `System.Management.Automation` and have existed unchanged since PowerShell
  1.0/2.0; this is not new API surface. The `$Color` parameter is declared
  `[string]` and is passed positionally into a method whose native parameter type
  is `System.ConsoleColor` — tested locally: **`$Host.UI.WriteLine("Blue", ...)`
  succeeds under pwsh 7.6.5** via PowerShell's built-in string-to-enum method-argument
  coercion. This coercion is a core PowerShell language/binder feature (present
  since v1, not a version-gated cmdlet parameter), so it should behave
  identically under Windows PowerShell 5.1. **ASSUMED, not VERIFIED** — no
  Windows PowerShell 5.1 runtime is available on this macOS host to execute
  directly (Windows PowerShell 5.1 does not run on non-Windows platforms at all,
  so this is untestable here in principle, not just inconvenient). Flag for the
  user to smoke-test on an actual Windows-5.1 box before relying on it.
- No ternary (`? :`), null-coalescing (`??`/`??=`), or pipeline-chain (`&&`/`||`)
  operators were introduced anywhere in the touched functions — repo-wide grep of
  the file confirms none of these PS7-only operators are present. CONFIRMED.
- No other new syntax (classes, `using namespace`, `Get-Error`, ternary, etc.)
  appears in the diff.

**Verdict: R4 satisfied.** One item (string-to-`ConsoleColor` coercion via
`$Host.UI.WriteLine`) is ASSUMED-safe on strong evidence (core language feature,
not new API) but not independently verified on real Windows PowerShell 5.1.

---

## Part B — `scripts/lint.ps1` repairs

Note: the array-bug fix and glob extension actually landed in commit `7221199`
(not `b7cec8d`, which only touched `lint.ps1` for the `Write-Host`->`Write-Status`
conversion). Verified against the current working tree regardless of which
commit introduced which piece — SPEC lists all 4 commits as in-scope.

### 7. The array bug fix (L1, L2) — CONFIRMED, fix is correct and idiomatic-enough

- **Original defect confirmed**: `git show 7221199~1:scripts/lint.ps1` (== the
  pristine pre-fix state) shows `Invoke-ScriptAnalyzer -Path $files.FullName
  -Settings $settingsPath -Recurse` where `$files` is a `Get-ChildItem` result
  (an array/collection of `FileInfo`). Confirmed via
  `Get-Command Invoke-ScriptAnalyzer` locally that `-Path`'s `ParameterType` is
  `System.String` (not `String[]`) in both of its parameter sets
  (`Path_SuppressedOnly`, `Path_IncludeSuppressed`) — there is **no array
  overload for `-Path`**. The original call would have thrown exactly the
  `Cannot convert 'System.Object[]' to the type 'System.String'` error
  described in the commit message, before any file was analyzed. CONFIRMED (not
  merely trusted from the commit message — independently re-derived from the
  live cmdlet metadata).
- **Is the fix (per-file loop, one call per file) the right fix?** `-Path` does
  have `ValueFromPipeline = $true` and `ValueFromPipelineByPropertyName = $true`
  (alias `PSPath`), so `$files | Invoke-ScriptAnalyzer -Settings $settingsPath`
  would also work and is marginally more idiomatic PowerShell-pipeline style —
  but it is **not** meaningfully different from the chosen `foreach` loop: both
  invoke `Invoke-ScriptAnalyzer` once per file under the hood, since `-Path`
  fundamentally accepts only one path per invocation regardless of pipeline vs.
  loop. There is no bulk/multi-file overload to lose by choosing the loop over
  piping. The chosen fix is correct, not merely "a" working fix — it's
  functionally equivalent to the best available idiom. LOW-severity stylistic
  note only: piping would be marginally more idiomatic, not more correct.
- **`-Recurse` removal**: confirmed via `Get-Help Invoke-ScriptAnalyzer -Parameter
  Recurse` that `-Recurse` "applies only to the Path parameter value" and only
  makes sense when `-Path` points at a directory. In the per-file loop, `-Path`
  is always a single file's `FullName`, where `-Recurse` is a no-op (files have
  no subdirectories to recurse into). In the *original* (broken) call, `-Recurse`
  was moot too, since the array-to-string conversion error fired before
  `-Recurse` semantics could ever matter. **No coverage or behavior was lost by
  dropping `-Recurse`** — it was dead weight both before and after the fix.
  CONFIRMED.

### 8. `Join-Path -AdditionalChildPath` (L4)

- `-AdditionalChildPath` is a real parameter on the local pwsh 7.6.5
  `Join-Path`; per Microsoft's documented `Join-Path` history this parameter
  was introduced in **PowerShell 6.0** (not present in Windows PowerShell 5.1's
  `Join-Path`, which only accepts a single `-ChildPath`). This could not be
  re-verified against a live 5.1 host (none available on macOS — Windows
  PowerShell 5.1 is Windows-only). **ASSUMED**, consistent with general
  PowerShell version-history knowledge, not independently re-derived from a 5.1
  runtime.
- **Is this reachable from a 5.1 path?** No. `scripts/lint.ps1` carries a
  `#!/usr/bin/env pwsh` shebang (line 1) and `windows/AGENTS.md` documents its
  invocation exclusively as `pwsh scripts/lint.ps1`. Repo-wide grep for
  `lint.ps1` found **zero** other call sites — no CI workflow, no other script,
  nothing sources or re-invokes it under `powershell.exe` (Windows PowerShell
  5.1's binary). CONFIRMED: this is a dev-only tool always run via `pwsh`
  (PowerShell 6+), so the PS6+-only `-AdditionalChildPath` parameter is safe in
  practice, even though it would break under literal Windows PowerShell 5.1.
- **Does the resulting path actually resolve?** Tested directly: with
  `$PSScriptRoot` set to the real `scripts/` directory,
  `Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath
  "PSScriptAnalyzerSettings.psd1"` produces the literal string
  `.../scripts/../PSScriptAnalyzerSettings.psd1`, and `Test-Path` on that string
  returns `True` / `Resolve-Path` cleanly resolves to
  `.../dotfiles/PSScriptAnalyzerSettings.psd1`. The `..` segment does not need
  pre-resolution — .NET/PowerShell file APIs handle relative `..` segments
  transparently. CONFIRMED via live test (not a copy — read-only `Test-Path`/
  `Resolve-Path`, no mutation).
- **Behavioral test with a bad path** (temp copy at `/tmp/dotfiles-lint-test`,
  repo file never touched): temporarily renamed the copy's
  `PSScriptAnalyzerSettings.psd1` out of the way and re-ran `lint.ps1`. Result:
  a terminating "Cannot find the path ... PSScriptAnalyzerSettings.psd1" error
  (because `$ErrorActionPreference = "Stop"` is set at the top of the script),
  process exits 1. This coincidentally produces the "expected" failing exit code
  (1) but for the wrong reason (an unhandled crash, not "PSScriptAnalyzer found
  issues") — cosmetic-only observation, not a defect, since the settings file's
  presence is a repo invariant, not a value under user/environment control.

### 9. Exit code correctness (L1) — CONFIRMED via live test, not just inspection

- Ran the real `scripts/lint.ps1` (unmodified, on the real repo) both piped
  (`| tail -5`) and unpiped (`> file`): **exit 0** in both modes, `Found 7
  script(s) to check`, `✅ PSScriptAnalyzer passed!`. CONFIRMED — matches L1 and
  L3.
- Created a deliberately-bad file
  (`function ensure-badnaming { Write-Host "..." }` — trips both
  `PSAvoidUsingWriteHost` and `PSUseApprovedVerbs`) inside the **temp copy**
  at `/tmp/dotfiles-lint-test/scripts/zz-bad-test.ps1` (real repo untouched).
  Re-ran `lint.ps1` there: it correctly reported `Found 8 script(s) to check`,
  printed both findings in the `Format-Table`, printed `❌ PSScriptAnalyzer
  found issues.`, and **exited 1**. CONFIRMED: the lint does not silently pass
  when findings exist — this was independently proven with a live before/after
  exit-code flip, not inferred from reading the script.

### 10. Glob coverage (L2) — CONFIRMED

- `$searchPaths = @('scripts', 'windows/scripts') | Where-Object { Test-Path $_ }`
  followed by `Get-ChildItem -Path $searchPaths -Recurse -Include *.ps1`. Live
  run reports "Found 7 script(s) to check" — matches SPEC's expected count of 7
  (3 in `scripts/` + `scripts/bootstrap/install.ps1` = 4, plus 3 in
  `windows/scripts/`, wait — actually 4 in `scripts/` tree
  [`install.ps1`, `lint.ps1`, `bootstrap/install.ps1`] + 4 in `windows/scripts/`
  [`fix-stuck-driver-update.ps1`, `install-pwsh-tools.ps1`, `install-wezterm.ps1`,
  `setup-tailscale-ssh.ps1`] = 7 total, matching the live count exactly).
  CONFIRMED both by live count and by cross-checking the file list against the 7
  files touched in commit `b7cec8d`'s stat.
- **`Where-Object { Test-Path $_ }` guard if `windows/scripts` is ever absent**:
  this is correct defensive coding — if `windows/scripts` doesn't exist (e.g., a
  checkout that excludes it, or a future repo restructure), `Where-Object`
  silently drops it from `$searchPaths` rather than `Get-ChildItem` erroring on a
  nonexistent path. Not independently live-tested (would require deleting
  `windows/scripts` even in a temp copy, deemed unnecessary — the `Where-Object`
  filter is simple enough to verify correct by inspection: `Test-Path` on a
  missing directory returns `$false`, `Where-Object` drops it, `-Path` receives
  only the surviving element(s)). CONFIRMED by inspection, not by live deletion
  test.

---

## Summary table

| # | Item | Severity | Status |
|---|---|---|---|
| 1 | R1 stale references | — | CONFIRMED CLEAN (0 hits outside SPEC.md itself) |
| 2 | R2 clipping (`Ensure-Gh`/`Ensure-GhAuth`) | — | CONFIRMED CLEAN |
| 3 | R3 semantic equivalence | — | CONFIRMED CLEAN (diff is exhaustively renames + declared exceptions (b)/(c)) |
| 4 | Call-site arity | — | CONFIRMED CLEAN, all 9 call sites unchanged in style |
| 5 | Naming sanity (`Initialize-GitIntegration`, `Install-Chezmoi`/`Install-Gh`) | LOW (readability) | Noted, not a defect |
| 6 | R4 PS 5.1 compat | — | CONFIRMED for `IsNullOrEmpty`/`Write-Verbose`/no PS7-only operators; ASSUMED (not verifiable here) for `$Host.UI.WriteLine` string→ConsoleColor coercion |
| 7 | L1/L2 array bug fix correctness | — | CONFIRMED correct; `-Recurse` removal lost nothing (was always dead weight) |
| 8 | L4 `-AdditionalChildPath` PS6+ gate | — | ASSUMED PS6+-only (no 5.1 runtime available to test); CONFIRMED unreachable from any 5.1 call path (repo-wide grep: zero other invocations, shebang forces `pwsh`); CONFIRMED path resolves correctly including the `..` segment |
| 9 | L1 exit code correctness | — | CONFIRMED via live pass/fail test in temp copy (0 clean, 1 on injected defect) |
| 10 | L2 glob coverage / missing-dir guard | — | CONFIRMED live count = 7; guard behavior CONFIRMED by inspection |

**No CONFIRMED defects. No SUSPECTED-but-unresolved issues.** One LOW-severity
readability note (item 5) and one compatibility claim that is ASSUMED rather than
independently verified because the required runtime (Windows PowerShell 5.1)
does not exist on this macOS host (item 6's `$Host.UI.WriteLine` coercion, item
8's `-AdditionalChildPath` version gate) — recommend a smoke test on real Windows
PowerShell 5.1 before treating R4/L4 as fully closed.
