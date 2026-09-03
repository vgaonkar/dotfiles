# Final Verdict — PowerShell driver fix + repo-wide lint cleanup

**Date:** 2026-09-02
**Target:** `~/Development/dotfiles` @ `main`
**Audits:** 6 parallel agents (driver logic, Windows APIs, Write-Status conversion,
renames + lint, destructive-operation safety, docs) + orchestrator cross-checks
**Toolchain:** PowerShell 7.6.5 + PSScriptAnalyzer on macOS. **No Windows machine.**

---

## Verdict

| Component | Before audit | After fixes |
|---|---|---|
| `scripts/` lint cleanup (49 findings) | GO | **GO** |
| 9 function renames | GO | **GO** |
| `lint.ps1` array-bug fix | GO | **GO** |
| `Write-Status` conversion | NO-GO (transcript + RawUI) | **GO** |
| `fix-stuck-driver-update.ps1` dry run | GO | **GO** |
| `fix-stuck-driver-update.ps1` `-Execute` | **NO-GO** | **CONDITIONAL GO** |

`-Execute` remains CONDITIONAL because the script has still never run on Windows.
Every defect found by static audit is fixed and re-verified; what cannot be settled
from macOS is listed under "Assumed, not verified" below.

---

## Defects found and fixed

| ID | Sev | Defect | Fix | Verified |
|----|-----|--------|-----|----------|
| F1/S1 | CRITICAL | `-Vendor` was an unvalidated regex gating every delete. `''`, `'.'`, `'win'`, `'store'`, `'system'` each selected **every** driver package (`OriginalFileName` is a full DriverStore path). | `ValidateNotNullOrEmpty` + `ValidateScript`: pattern must compile and must not match a canary set of unrelated drivers. Match narrowed to `ProviderName` only. | 8 dangerous patterns rejected; 4 real vendor names accepted |
| S2 | CRITICAL | Same over-broad match fed `DenyDeviceIDs` + `Retroactive=1` for every device. | Same validation gate. | as above |
| F2 | HIGH | `Get-WindowsDriver -Online -All` includes Microsoft **inbox** drivers, which then reached `pnputil /delete-driver /force`. | Dropped `-All`; added `Driver -like 'oem*.inf'` guard. | code inspection |
| F5/W4 | HIGH | `Start-Transcript` does **not** capture `$Host.UI.WriteLine`, so `run.log` held only header + footer while the script twice told the user to read it. | `Write-Status` now uses `Write-Host` with a scoped `SuppressMessageAttribute`. | markers CAPTURED in a real script-file transcript |
| W-2 | HIGH | Coloured branch read `$Host.UI.RawUI.BackgroundColor` with no `try/catch`, unlike Microsoft's `Write-Host`; would throw on a non-interactive host — including the fresh-machine PS 5.1 bootstrap. | Same fix removed all `RawUI` access. | `grep`: zero `RawUI` references remain |
| F3 | HIGH | `-Verify` deduped failures by `Title\|Code` with no date, so the same driver failing again — the exact recurrence being tested for — was filtered out as "already seen" and reported PASS. | Dedup key now includes the ISO timestamp. | code inspection |
| F4/S6 | HIGH | `DenyDeviceIDs` append used `.Count`, not max, so entries numbered 1,2,5 caused entry 5 to be **overwritten**. Violated invariant D7. | Index continues from `Measure-Object -Maximum`. | code inspection |
| S3 | HIGH | No `try/finally` across the service stop→start window; an abort left wuauserv/BITS/CryptSvc stopped. | Whole window wrapped in `try/finally`; prior running-state recorded so stopped services are not started. | code inspection |
| S4 | HIGH | Backup "verification" was presence-only and ignored `pnputil`'s exit code. | Now requires exit 0 **and** ≥1 file **and** non-zero total bytes **and** ≥1 `.inf`. | code inspection |
| S5 | HIGH | Recommended workflow was self-defeating: `-BlockByHardwareId` blocks all installs for the hardware, including the vendor driver the next step tells you to install. Restore guidance was a single placeholder path. | Summary reordered (block only after the printer works); explicit warning at block time; `RESTORE.md` generated **before** the purge with real per-package paths and `Add-Printer` commands. | generated and inspected |
| S8 | MEDIUM | Phase 4 renames `SoftwareDistribution`, which is where `QueryHistory` reads — guaranteeing a false PASS on the history check. | `-Verify` detects the `.old.*` sibling and reports **SKIP**, not PASS. | code inspection |
| F8 | MEDIUM | Null baseline made every historical failure look new → false FAIL. | Reports SKIP when there is no baseline. | code inspection |
| F9 | MEDIUM | `ResultCode` 1 (InProgress) and 3 (SucceededWithErrors) counted as failures. | Only 4 (Failed) and 5 (Aborted) count. | Microsoft enum confirmed |
| F6 | MEDIUM | Ghost-device removal never read `$LASTEXITCODE` and always printed success. | Exit code checked; failure raises a warning. | code inspection |
| — | HIGH | Both block mechanisms are **Pro/Enterprise/Education/IoT only**; on Home the registry writes succeed and Windows silently ignores them. | `Test-PolicySupport` reads the edition and warns loudly that the block is ineffective. | Microsoft edition table |

## Verified clean (no defects)

- **169 `Write-Host` → `Write-Status` conversions across 6 files: zero mismatches** in
  message text, argument count, or colour. The 4 calls inside the here-string that
  builds a generated script were correctly left as `Write-Host`.
- **9 function renames:** zero stale references repo-wide; full diff contains nothing
  beyond the renames, the conversion, and the one empty-catch fix; `Ensure-Gh` did not
  clip `Ensure-GhAuth`.
- **`lint.ps1`:** array-bug fix correct (`-Path` confirmed string-only via live cmdlet
  metadata); dropping `-Recurse` lost nothing; exit codes live-tested 0/1 in a `/tmp` copy.
- **Windows APIs:** no claim found wrong. `pnputil` flags, `Remove-PrinterDriver`
  parameter, `Get-PnpDeviceProperty`, `Get-PnpDevice`, `QueryHistory`,
  `OperationResultCode`, both registry policy paths, and `Get-WindowsUpdateLog`
  all match Microsoft Learn exactly. The `QueryHistory` count-zero guard is correct —
  the API does throw there.
- **Docs:** every flag, path, exit code, and behavioural claim matches the code.

## Assumed, not verified (no Windows machine)

1. `Get-WindowsDriver`'s property names — the official page documents only opaque
   output types. If a name is wrong, `Select-Object` silently yields blank columns.
2. The `DenyDeviceIDs` numbered-subkey layout the append logic depends on —
   corroborated only by non-Microsoft sources.
3. `WindowsUpdate\Auto Update\RebootRequired` as a pending-reboot signal — not found
   in any primary source. Under-reports rather than over-reports if wrong.
4. Service names and `usosvc` stop-tolerance on Windows 11.
5. `0x800f020b` / `0x80070103` meanings — Microsoft Q&A consensus, no canonical page.
   Both drive advisory text only, never control flow.
6. Windows PowerShell 5.1 behaviour of the bootstrap scripts — no 5.1 runtime exists
   on macOS. No PS6+-only construct was found by grep.

## Remaining accepted risks

- **No interactive confirmation in `-Execute`.** The vendor guard now bounds the blast
  radius, and the dry run shows the plan, but there is no "delete N packages?" prompt
  and no `-WhatIf`. Accepted: the operator is the author's user, running deliberately.
- **Printers are removed without a per-queue backup**, but `RESTORE.md` now records
  name, driver, and port for each, which is enough to recreate them.
- **Doc-accuracy nit:** the SPEC said "163 conversions across 7 files"; the true figure
  is 169 across 6 (the driver script was born using `Write-Status`).

## Recommended execution path

1. Dry run: `.\fix-stuck-driver-update.ps1 -Vendor Canon`
2. Read the plan, confirm only Canon packages are listed.
3. `.\fix-stuck-driver-update.ps1 -Vendor Canon -Execute`
4. Reboot. `.\fix-stuck-driver-update.ps1 -Vendor Canon -Verify`
5. Install Canon's driver from Canon's site.
6. **Only if it comes back:** re-run with `-SkipDriverPurge -SkipUpdateReset -BlockByHardwareId`.
