# Verification Spec — PowerShell driver fix + repo-wide lint cleanup

> Written 2026-09-02 as the reference document for `/deep-verify`. This is not a
> forward-looking plan; it is a statement of what was changed in this session and
> the invariants each change must satisfy. Agents verify the code against this.

**Target:** `~/Development/dotfiles`, branch `main`
**Commits under audit:** `259068c`, `7221199`, `7543364`, `b7cec8d`
**Toolchain available:** PowerShell 7.6.5 + PSScriptAnalyzer on macOS (arm64)
**Not available:** any Windows machine. Windows-only cmdlet *behaviour* cannot be
executed and must be reported as ASSUMED, never as VERIFIED.

---

## Change 1 — New script `windows/scripts/fix-stuck-driver-update.ps1`

Repairs the Windows Update failure mode where a vendor driver (observed: Canon
`2.90.2.30`) is permanently pending, fails each install (typically `0x800f020b`),
and re-arms the shutdown update prompt because the pending-reboot flag never clears.

Six phases: diagnose → back up → purge → reset update state → block redelivery →
repair component store.

### Invariants

| ID | Invariant |
|----|-----------|
| D1 | With no `-Execute`, the script performs **zero** mutations. Every write, delete, service stop, rename, and registry set is gated. |
| D2 | No driver package is deleted until its `pnputil /export-driver` output is confirmed present on disk. Count mismatch aborts with exit 2 *before* any delete. |
| D3 | The script refuses to run unelevated (exit 1). |
| D4 | `-Execute` and `-Verify` are mutually exclusive (exit 1), and the guard fires before any other work. |
| D5 | `SoftwareDistribution` / `catroot2` are **renamed**, never deleted. |
| D6 | Registry policy keys are exported via `reg export` before any value is written. |
| D7 | `-BlockByHardwareId` appends to existing `DenyDeviceIDs` numbered values; it never clobbers entries it did not create. |
| D8 | `-Verify` is read-only and returns exit 3 when the fix did not hold, exit 0 when it did. |
| D9 | `-Verify` must not report a false failure when the printer is legitimately reinstalled afterwards — only *new* failures relative to the baseline count. |
| D10 | Exit codes: 0 ok, 1 not elevated / bad args, 2 backup verification failed, 3 verify failed. |
| D11 | Comment-based help resolves: 9 parameters, 4 examples. (A `#!` shebang suppresses this — must remain absent.) |

---

## Change 2 — `Write-Host` → `Write-Status` across all 7 `.ps1` files

`PSAvoidUsingWriteHost` is in `PSScriptAnalyzerSettings.psd1`'s `IncludeRules`.
163 `Write-Host` calls were converted to a `Write-Status` helper built on
`$Host.UI.WriteLine`.

### Invariants

| ID | Invariant |
|----|-----------|
| W1 | Console output is visually unchanged: same text, same colours. |
| W2 | The 4 `Write-Host` calls inside `setup-tailscale-ssh.ps1`'s here-string are **untouched** — that text is a generated script written to the user's machine which has no `Write-Status` helper. Rewriting them would break it. |
| W3 | `Write-Status` must not throw when there is no real console. `$Host.UI.RawUI.ForegroundColor` returns `-1` under redirection and `WriteLine` rejects `-1` as a *foreground* (tolerates it as background). Uncoloured calls must use the plain overload. |
| W4 | Output remains captured by `Start-Transcript`. |
| W5 | No call site lost or gained an argument during conversion. |

---

## Change 3 — 9 function renames in `scripts/bootstrap/install.ps1`

For `PSUseApprovedVerbs` and `PSUseSingularNouns`:

| Old | New |
|-----|-----|
| `To-Bool` | `ConvertTo-Boolean` |
| `Ensure-EnvDefault` | `Initialize-EnvDefault` |
| `Ensure-Chezmoi` | `Install-Chezmoi` |
| `Ensure-Gh` | `Install-Gh` |
| `Ensure-GhAuth` | `Initialize-GhAuth` |
| `Refresh-PathForGh` | `Update-PathForGh` |
| `Maybe-SetupGit` | `Initialize-GitIntegration` |
| `Run-Chezmoi` | `Invoke-Chezmoi` |
| `Add-ToPathIfExeExists` | `Add-ExeDirectoryToPath` |

### Invariants

| ID | Invariant |
|----|-----------|
| R1 | Zero stale references to any old name anywhere in the repo — including docs, README, `site/`, and shell scripts, not just `.ps1`. |
| R2 | `Ensure-Gh` substitution did not clip `Ensure-GhAuth`. |
| R3 | Bootstrap control flow and semantics are byte-for-byte equivalent apart from identifiers. |
| R4 | This script runs on a **fresh machine** via `#Requires -Version 5.1` — Windows PowerShell 5.1, not just pwsh 7. Any construct used must be 5.1-compatible. |

---

## Change 4 — `scripts/lint.ps1` repairs

Two defects, both pre-existing and confirmed present on a pristine checkout:

1. `Invoke-ScriptAnalyzer -Path` takes a single string; it was passed
   `$files.FullName` (an array), throwing
   `Cannot convert 'System.Object[]' to the type 'System.String'`. The lint never
   analysed anything — it crashed before reporting. Now analyses one file at a time.
2. The glob covered only `scripts/`, never `windows/scripts/`, despite
   `windows/AGENTS.md` requiring those files to pass. Glob extended.

### Invariants

| ID | Invariant |
|----|-----------|
| L1 | Lint exits 0 only when there are genuinely zero findings, and 1 when any exist. It must not silently pass. |
| L2 | All 7 scripts are analysed (count reported = 7). |
| L3 | Works both piped and unpiped. |
| L4 | `Join-Path -AdditionalChildPath` requires PowerShell 6+. `lint.ps1` is a dev-only tool run via `pwsh`, so this is acceptable — but confirm it is not reachable from any 5.1 path. |

---

## Change 5 — Documentation

`docs/05-troubleshooting.md` gained a Windows section; `windows/AGENTS.md` records
the new script and the lint-glob coverage.

| ID | Invariant |
|----|-----------|
| X1 | Every flag and path shown in the docs exists and behaves as described. |
| X2 | No doc references a flag that was renamed during the session (`-DisableDriverUpdate` still exists; `-BlockByHardwareId` is the recommended one). |

---

## Out of scope

- Executing anything against a live Windows machine.
- Modifying the target repo (this is a read-only audit; the fix loop may revise
  *this spec*, never the scripts).
