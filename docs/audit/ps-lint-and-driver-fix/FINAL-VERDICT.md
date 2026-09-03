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
| F1/S1 | CRITICAL | `-Vendor` was an unvalidated regex gating every delete. `''`, `'.'`, `'win'`, `'store'`, `'system'` each selected **every** driver package (`OriginalFileName` is a full DriverStore path). | **SUPERSEDED by C1 below — this fix was inadequate.** Canary validation kept as a cheap filter; the real bound is now `-MaxPackage` + typed confirmation. Match narrowed to `ProviderName` only. | see C1 |
| S2 | CRITICAL | Same over-broad match fed `DenyDeviceIDs` + `Retroactive=1` for every device. | Same gate as F1/S1 — see C1. | see C1 |
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

- ~~No interactive confirmation in `-Execute`.~~ **Resolved in round 2** — `-Execute`
  now lists every matched package and requires the vendor name typed back, and
  `-MaxPackage` refuses outright above the cap. There is still no native `-WhatIf`;
  the `-Execute` gate serves that role.
- **The final safety layer is a human reading a list.** `-MaxPackage` catches the wide
  patterns automatically, but a pattern matching a handful of unrelated vendors passes
  the cap and is caught only by the operator reading the provider names in the
  confirmation prompt. Read it.
- **Printers are removed without a per-queue backup**, but `RESTORE.md` now records
  name, driver, and port for each, which is enough to recreate them.
- **Doc-accuracy nit:** the SPEC said "163 conversions across 7 files"; the true figure
  is 169 across 6 (the driver script was born using `Write-Status`).

## Phase 3 — adversarial pass over the fixes (round 2)

An adversarial critic and an invariant verifier re-examined the 14 fixes above.
The verifier returned PASS on every invariant it could test (W3 obsolete by design;
W1/W4-proof/R4 CANNOT-VERIFY without Windows). The critic broke one fix outright.

| ID | Sev | Finding | Fix |
|----|-----|---------|-----|
| C1 | **CRITICAL** | **The vendor canary guard was security theatre.** The 5 canary strings happen not to contain the letters `b g h j q z`, so `-Vendor 'h'` passed and matched Brother, HP, Logitech, Ricoh, Zebra. A negative-lookahead pattern passed and matched 31 of 31 real vendors. The guard only ever caught the naive mistakes it was written against. | Blast radius is now bounded **at the point of destruction**, not by pattern inspection: `-MaxPackage` (default 5) refuses the run, and `-Execute` requires the operator to **type the vendor name** after seeing the exact package list. The canary is kept, demoted in comments to a cheap early filter. |
| C2 | HIGH | `RESTORE.md` was written only in the purge branch, so the `-SkipDriverPurge -BlockByHardwareId` run — the script's own recommended step 6, and the hardest change to diagnose later — produced no undo guide while the summary pointed at one. | Hoisted: written for every `-Execute` run before any phase acts. |
| C3 | MEDIUM | `Test-PolicySupport` matched `'Home'` against `Win32_OperatingSystem.Caption`, which is **localised**. A French or Chinese Home user got no warning — the dangerous direction. | Uses `EditionID` (invariant; Home ships as `Core*`), with the caption shown only as a label. |
| C4 | MEDIUM | The `-Verify` history check tested for the mere existence of a `SoftwareDistribution.old.*` folder, which is never removed — so it went permanently dead after the first run. | Only a `.old` folder newer than the baseline counts as a reset. |
| C5 | LOW | `RESTORE.md` emitted unescaped single quotes; a printer named `Bob's Printer` broke (or could inject into) a command the operator is told to run elevated. | Apostrophes doubled. |
| C6 | LOW | `[int]` cast on a `DenyDeviceIDs` entry name would throw on an oversized value, aborting mid-registry-write. | `[long]::TryParse`, unparseable names skipped with a warning. |
| C7 | LOW | If `Get-WindowsDriver`'s property names are wrong (the top assumed-not-verified risk), the filter silently matches nothing and reads as "clean". | Fails loud: warns that the result is unreliable if `Driver`/`ProviderName` are absent. |

### Honest note on C1

`-MaxPackage` alone does not fully solve it: `-Vendor 'h'` matches exactly 5 packages
in the test set and therefore passes the cap. The second layer is what catches it —
`-Execute` prints every matched package with its provider name and requires the vendor
name typed back. That is a **human** check, not an automated one.

Verified: the confirmation fails **closed** in every non-interactive case (stdin
closed, empty pipe, wrong answer all abort; only the exact vendor name proceeds), so
it cannot be silently auto-answered by a scheduled task or a piped invocation.

---

## Round 3 — the critic's two "cannot verify" items

The critic closed by naming two things it refused to assert. Both were followed up.

### Resolved in code: JSON date rehydration (would have caused a false FAIL)

The `-Verify` dedup cast dates back out of `diagnosis.json`. Windows PowerShell 5.1
and PowerShell 7 use different JSON deserialisers, and a `DateTimeKind` difference
would make every historical failure look new — exit 3 on a machine that was actually
fixed.

Replaced the cast with a `DateKey` computed once from the live COM `DateTime` and
compared as a plain string. The first attempt used an ISO-8601 string and **was
broken** — testing showed `ConvertFrom-Json` recognises ISO strings and silently
converts them back to `DateTime`, so the baseline key rendered as `08/30/2026 17:42:11`
and never matched. Formats were measured rather than assumed:

| Format | Returns as | Round-trips identical |
|---|---|---|
| `o` (ISO round-trip) | DateTime | **No** |
| `s` (ISO sortable) | DateTime | **No** |
| `yyyyMMddHHmmssfffffff` | String | Yes |
| **UTC ticks** | **String** | **Yes** |

Now uses UTC ticks. Verified both directions: the known failure is filtered (no false
FAIL) and a recurrence one second later is still detected as new.

### Still unverified: `SuppressMessageAttribute` under Windows PowerShell 5.1

`scripts/install.ps1` and `scripts/bootstrap/install.ps1` are `#Requires -Version 5.1`
fresh-machine bootstraps. If the attribute fails to parse under 5.1, that is a **total
bootstrap failure introduced by this work** — the worst possible regression, on the one
script that runs before anything else exists.

It is a plain .NET attribute, it is the syntax PSScriptAnalyzer's own docs prescribe,
and PSSA treats 5.1 as a first-class host, so it very likely parses. That is not the
same as knowing. **Run this on any Windows box before trusting the bootstrap:**

```powershell
powershell.exe -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw scripts\bootstrap\install.ps1)) | Out-Null; 'PARSED OK'"
```

Cosmetic, fixed alongside: dead `switch` arms for ResultCode 1/3 removed, and the
"Non-successful update history" label corrected to "Failed/aborted update history".

---

## Recommended execution path

1. Dry run: `.\fix-stuck-driver-update.ps1 -Vendor Canon`
2. Read the plan. **Confirm only Canon packages are listed** — this is the real
   safety check, and the script will make you type the vendor name to proceed.
3. `.\fix-stuck-driver-update.ps1 -Vendor Canon -Execute`
4. Reboot. `.\fix-stuck-driver-update.ps1 -Vendor Canon -Verify`
5. Install Canon's driver from Canon's site.
6. **Only if it comes back:** re-run with `-SkipDriverPurge -SkipUpdateReset -BlockByHardwareId`.
