# Invariant Re-Check — PowerShell driver fix + repo-wide lint cleanup

**Date:** 2026-09-02
**Repo:** `~/Development/dotfiles` @ `main`, commit `c6d99bc` (fixes landed in `dadd2cb`)
**Toolchain used:** pwsh 7.6.5 + PSScriptAnalyzer on macOS (arm64). No Windows machine.
**Method:** Every verdict below is based on evidence produced in this run — line-by-line
tracing of `windows/scripts/fix-stuck-driver-update.ps1`, live `pwsh`/`Invoke-ScriptAnalyzer`
runs, `git show`/`grep` history checks, and one live JSON round-trip test. Nothing is
carried over from the prior audit files as-is; where this recheck agrees with them it is
because independent evidence reached the same conclusion.

---

## Summary table

| ID | Verdict | Evidence (one line) |
|----|---------|----------------------|
| D1 | PASS | Traced all 5 mutation-capable functions + all call-site `Save-*`/`New-Item`/`Start-Transcript` writes; every one is behind `-not $Execute { return }` or an inline `if ($Execute)`. |
| D2 | PASS | `Export-VendorDriver` returns `$false` on any package failing exit-code+file+bytes+`.inf` check (`windows/scripts/fix-stuck-driver-update.ps1:425-441`); caller aborts with `exit 2` (line 1060) before `Remove-VendorDriver` is ever called (line 1070). |
| D3 | PASS | `Test-Administrator` check at line 971, `exit 1` if false, runs before any diagnosis or mutation. |
| D4 | PASS | `$Execute -and $Verify` check is the very first executable statement after the banner (line 964), before `Test-Administrator` and everything else. |
| D5 | PASS | `Reset-UpdateComponent` only calls `Rename-Item` on `SoftwareDistribution`/`catroot2` (line 587); no `Remove-Item` on either path anywhere in the file. |
| D6 | PASS | Both `Disable-DriverUpdate` (line 626 export, 634-635 write) and `Disable-DeviceInstall` (line 667 export, 675-701 write) call `reg.exe export` before any `Set-ItemProperty`/`New-Item` on the policy key. |
| D7 | PASS | Append logic re-derives `$index` from `Measure-Object -Maximum` over existing numbered property names (lines 682-694), not `.Count` — confirmed by reading the code; a 1,2,5-numbered deny list would continue from 6, not overwrite 5. |
| D8 | PASS | `-Verify` branch (lines 980-1010) calls only `Get-Diagnosis`/`Get-LastDiagnosis`/`Show-Diagnosis`/`Test-FixResult`, none of which write; exits 0 on `$verifyFailures.Count -eq 0`, exit 3 otherwise. |
| D9 | PASS | The update-history check dedups by `Title\|Code\|Date` (ISO `'o'` format), so only *genuinely new* failures fail the check; live-tested that a `[datetime]` round-trips through `ConvertTo-Json`/`ConvertFrom-Json` to an identical key string. |
| D10 | PASS | Exactly 5 `exit` statements in the file (lines 968, 975, 995, 1009, 1060) covering 1/1/0/3/2 — matches the documented 0/1/2/3 set exactly; no new exit code introduced. Normal dry-run/execute completion falls off the end of the script (implicit 0). |
| D11 | PASS | Live `Get-Help -Full`: 9 parameters, 4 examples, resolves cleanly (no shebang, no other help-suppressing construct). |
| W1 | CANNOT-VERIFY (partial) | Text/argument identity verified structurally (see W5); actual on-screen colour rendering requires a real Windows console session. |
| W2 | PASS | The 4 `Write-Host` calls inside `setup-tailscale-ssh.ps1`'s here-string (lines 560, 564, 566, 570) are untouched and confirmed to sit inside a `@"..."@` block written out as a *separate generated script* (`omc-cleanup.ps1`), not executed by the parent script. |
| W3 | OBSOLETE AS WRITTEN — replacement verified | The `$Host.UI.WriteLine` design W3 describes no longer exists (removed in `dadd2cb`, see below). Current design: plain `Write-Host`, scoped `SuppressMessageAttribute`. Live-tested calling the current helper under output redirection (non-interactive-like context) with both plain and coloured calls — no exception. Full non-interactive-host colour behaviour (the original `RawUI.BackgroundColor` throw path) cannot be re-tested without a real Windows non-interactive host. **Replacement invariant:** "`Write-Status` must not throw regardless of host interactivity; it must not read `$Host.UI.RawUI.*` directly (only `Write-Host`'s own, already-hardened, handling of `-ForegroundColor`)." |
| W4 | PASS (design), CANNOT-VERIFY (full Windows proof) | `Write-Status` now calls `Write-Host`, which is Microsoft-documented as the console writer `Start-Transcript` captures; confirmed identical implementation with the `SuppressMessageAttribute` in all 6 converted files. Cannot execute `Start-Transcript` capture end-to-end on macOS. |
| W5 | PASS | Total `Write-Status` call sites (excluding the 6 helper-definition lines) across the 6 converted files = **169**, matching the corrected spec count exactly; recomputed independently via `grep -c` per file, not copied from the spec. |
| R1 | PASS | Word-boundary regex search for all 9 old names across the entire repo (excluding `docs/audit/` history and `.git/`) returns zero hits; `git status --short` confirmed no stray edits from testing. |
| R2 | PASS | `Install-Gh` (from `Ensure-Gh`) and `Initialize-GhAuth` (from `Ensure-GhAuth`) both exist as distinct, correctly-named functions — `Ensure-Gh` was not clipped. |
| R3 | PASS WITH ONE NOTED EXCEPTION | `git show b7cec8d -- scripts/bootstrap/install.ps1` is otherwise a pure identifier-rename + `Write-Host`→`Write-Status` diff, **except** one empty `catch {}` block (in what is now `Update-PathForGh`) gained a `Write-Verbose` call. This is a deliberate, documented improvement (commit message: "1 empty catch block given a Write-Verbose"), not a rename side-effect, and does not change control flow (the catch still swallows and continues) — but it is not "byte-for-byte identical apart from identifiers" as D-series wording states literally. Flag as a known, harmless deviation from the literal invariant text. |
| R4 | CANNOT-VERIFY | `#Requires -Version 5.1` is present and nothing added since (`ConvertTo-Boolean`, ternary-free, no `??`, no `-AdditionalChildPath` used in this file) reads as 5.1-compatible by inspection, but actual execution under Windows PowerShell 5.1 cannot be performed from this macOS/pwsh-7.6.5 environment. |
| L1 | PASS | Live-tested both directions: clean tree exits 0; injected a genuine `PSUseApprovedVerbs`/`PSAvoidUsingWriteHost` finding into a scratch copy of `fix-stuck-driver-update.ps1` and reran — exited 1 with the finding printed. Working tree confirmed clean afterward (`git status --short` empty). |
| L2 | PASS | Live run reports "Found 7 script(s) to check," matching the 7 `.ps1` files under `scripts/` + `windows/scripts/`. |
| L3 | PASS | Live-tested both `pwsh -File scripts/lint.ps1 | cat` (piped) and direct execution redirected to a file (unpiped/captured) — exit 0 both ways, same output. |
| L4 | PASS | `grep` confirms `lint.ps1` is referenced only from docs (`scripts/AGENTS.md`, `windows/AGENTS.md`) as a manually-invoked `pwsh scripts/lint.ps1` command; it is never called from `scripts/bootstrap/install.ps1` (the `#Requires -Version 5.1` fresh-machine path) or any other script. Not reachable from a 5.1 execution path. |
| X1 | PASS | Every flag/path in `docs/05-troubleshooting.md`'s Windows section (`-Vendor`, `-Execute`, `-Verify`, `-SkipDriverPurge`, `-SkipUpdateReset`, `-BlockByHardwareId`, `-DisableDriverUpdate`, `-RepairImage`, the `%USERPROFILE%\dotfiles-backups\driver-fix\<timestamp>\` path, `RESTORE.md`) is confirmed present and behaves as described by direct code inspection of the corresponding script logic. |
| X2 | PASS | `-DisableDriverUpdate` still exists as a switch (line 116); docs correctly recommend `-BlockByHardwareId` as the preferred, narrower option. |
| — (new finding) | **FAIL** | `windows/AGENTS.md:38-39` still says the `Write-Status` helper uses `$Host.UI.WriteLine` — this is stale. The actual, current implementation (since `dadd2cb`) is `Write-Host` + a scoped `SuppressMessageAttribute`. This doc line was not updated when the design changed and should be corrected. |

---

## Reference: every `exit` statement in the current file

| Line | Condition | Exit code | Matches spec? |
|------|-----------|-----------|---------------|
| 968 | `-Execute` and `-Verify` both passed | 1 | Yes (bad args) |
| 975 | `Test-Administrator` returns `$false` | 1 | Yes (not elevated) |
| 995 | `-Verify` mode, `$verifyFailures.Count -eq 0` | 0 | Yes (ok) |
| 1009 | `-Verify` mode, `$verifyFailures.Count -gt 0` | 3 | Yes (verify failed) |
| 1060 | `-Execute`, backup verification failed in `Export-VendorDriver` | 2 | Yes (backup verification failed) |
| *(none)* | Normal dry-run or successful `-Execute` completion | 0 (implicit, falls off end of script) | Yes (ok) |

No exit code outside `{0,1,2,3}` exists anywhere in the file.

## Reference: every mutation-capable operation and its guard

| Operation | Location | Guard |
|-----------|----------|-------|
| `New-Item`/export dir + `pnputil /export-driver` | `Export-VendorDriver` (403-433) | `if (-not $Execute) { ...; return $true }` at function top |
| `Remove-Printer` | `Remove-VendorDriver` (463-470) | `if ($Execute)` inline |
| `Restart-Service Spooler` | `Remove-VendorDriver` (485) | `if ($Execute)` inline |
| `Remove-PrinterDriver` (both attempts) | `Remove-VendorDriver` (490-503) | `if ($Execute)` inline |
| `pnputil /delete-driver ... /force` | `Remove-VendorDriver` (509-520) | `if ($Execute)` inline |
| `pnputil /remove-device` | `Remove-VendorDriver` (528-538) | `if ($Execute)` inline |
| `Stop-Service` / `Rename-Item` / `Start-Service` on update components | `Reset-UpdateComponent` (556-609) | `if (-not $Execute) { return }` at function top, plus `try/finally` around the stop→start window |
| `reg.exe export` + `Set-ItemProperty` (ExcludeWUDriversInQualityUpdate) | `Disable-DriverUpdate` (622-639) | `if (-not $Execute) { return }` at function top |
| `reg.exe export` + `New-Item`/`Set-ItemProperty` (DenyDeviceIDs) | `Disable-DeviceInstall` (663-712) | `if (-not $Execute) { return }` at function top |
| `dism.exe /restorehealth`, `sfc.exe /scannow` | `Invoke-ImageRepair` (718-741) | `if (-not $Execute) { return }` at function top |
| `Set-Content` (diagnosis.json) | `Save-Diagnosis`, called line 1041 | `if ($Execute)` at call site |
| `Set-Content` (RESTORE.md) | `Save-RestoreNote`, called line 1065 | `if ($Execute)` at call site |
| `Get-WindowsUpdateLog` (writes WindowsUpdate.log) | `Save-UpdateLog`, called line 1112 | `if ($Execute -and $script:WarningCount -gt 0)` at call site |
| `New-Item` ($runDir) + `Start-Transcript` | Main block (1027-1029) | `if ($Execute)` wrapping both |

Non-mutating (no guard needed, confirmed read-only): `Get-VendorPrinter`, `Get-VendorDevice`,
`Get-VendorDriverPackage`, `Get-VendorHardwareId`, `Get-UpdateFailure`, `Get-PendingRebootFlag`,
`Get-Diagnosis`, `Show-Diagnosis`, `Get-LastDiagnosis`, `Test-PolicySupport`, `Test-FixResult`
(reads only), `Test-Administrator`.

---

## Notable results from this recheck

1. **All D-series invariants PASS** on direct code tracing, including the three the team
   lead specifically flagged (D1, D2, D7) and D10/D11 which were re-run live.
2. **W3 is confirmed obsolete as written** — the `$Host.UI.WriteLine` design it describes
   was removed in `dadd2cb`. Proposed replacement invariant given above.
3. **One new stale-doc finding**: `windows/AGENTS.md:38-39` describes the old
   `$Host.UI.WriteLine`-based helper, which no longer matches the code. This is outside the
   SPEC's X1/X2 scope (those cover `docs/05-troubleshooting.md` and driver-fix flags only)
   but is the same class of defect and should be fixed.
4. **R3 has one small, deliberate deviation** from "byte-for-byte apart from identifiers":
   an empty catch block gained a `Write-Verbose` call. Harmless, but the literal invariant
   text is not 100% true.
5. **Everything requiring a live Windows session remains CANNOT-VERIFY** (W1 full colour
   rendering, W4 full transcript-capture proof, R4 execution under real 5.1). These were
   correctly identified as assumptions in the original audit and nothing in this recheck
   changes that status — no Windows machine was available here either.
