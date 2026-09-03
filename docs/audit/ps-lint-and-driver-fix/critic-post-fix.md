# Adversarial post-fix review — driver fix + Write-Status conversion

**Date:** 2026-09-02
**Target:** `~/Development/dotfiles` @ `main` (`c6d99bc`), fixes in `dadd2cb`
**Method:** hostile re-verification of every fix claimed in `FINAL-VERDICT.md`.
Executed on PowerShell 7.6.5 + PSScriptAnalyzer 1.25.0 on macOS. **No Windows machine.**
Prior assumption: every fix is wrong until proven otherwise.

Each finding states whether it was **CONFIRMED BY EXECUTION** or **by inspection only**.

---

## Summary

| ID | Sev | Finding | Evidence |
|----|-----|---------|----------|
| C1 | **CRITICAL** | The `-Vendor` canary guard is bypassable and does not bound blast radius | executed |
| C2 | **HIGH** | `RESTORE.md` is not written on the one run that installs the device block | inspection |
| C3 | MEDIUM | `Test-PolicySupport` fails **open** on localised Windows (Home user gets no warning) | executed + primary source |
| C4 | MEDIUM | The `-Verify` history check is permanently dead after the first `-Execute`, not skipped once | executed |
| C5 | LOW | `RESTORE.md` emits unescaped single quotes — apostrophe in a printer name breaks/injects the line | executed |
| C6 | LOW | Unguarded `[int]` cast in the `DenyDeviceIDs` max aborts mid-write | executed |
| C7 | LOW | The narrowed package match has no fail-loud path; a wrong property name reads as success | inspection |

Fixes I attacked and **could not break** are listed at the end, with the two things
I could not verify at all stated plainly.

---

## C1 — CRITICAL — the vendor canary guard does not do what the verdict claims

**File:** `windows/scripts/fix-stuck-driver-update.ps1:94-112`
**Claim under test:** "8 dangerous patterns rejected, 4 real vendor names accepted."
**Status: CONFIRMED BY EXECUTION** — the script was invoked with each pattern below and
its accept/reject observed at parameter-binding time.

### Total bypass

```
.\fix-stuck-driver-update.ps1 -Vendor '^(?!Microsoft|Intel|NVIDIA|Realtek|C:).*$'
```

**Accepted.** Against a 31-name sample of realistic third-party `ProviderName` values
(Canon, Brother, Hewlett-Packard, Epson, Logitech, Qualcomm, Broadcom, ASUSTeK, AMD,
Synaptics, Dell, Lenovo, Samsung, Seagate, Western Digital, Razer, Corsair, Elgato,
Google, Apple, MediaTek, Ricoh, Xerox, Kyocera, Zebra, Fujitsu, Sony, Nikon, Wacom,
SteelSeries …) it matches **31 of 31**. The pattern is constructed to step around the
exact five canary strings and nothing else.

What that deletes: `pnputil /delete-driver /uninstall /force` against **every
third-party driver package on the machine**, every matching printer and printer driver,
every matching ghost device, and — with `-BlockByHardwareId` — `DenyDeviceIDs` plus
`DenyDeviceIDsRetroactive=1` covering every hardware ID on the box.

### Accidental bypass — any single letter absent from the canaries

The five canaries collectively contain most of the alphabet. The letters they do **not**
contain are `b g h j q z`. Each is accepted as a standalone `-Vendor`:

| `-Vendor` | verdict | real vendors selected |
|---|---|---|
| `h` | **ACCEPTED** | Brother, Hewlett-Packard, HP Inc., Logitech, Ricoh, Zebra Technologies |
| `b` | **ACCEPTED** | Brother, Broadcom, Zebra Technologies |
| `g` | **ACCEPTED** | Logitech, Samsung, Seagate, Western Digital, Elgato, Google, Zebra |
| `[bghjqz]` | **ACCEPTED** | 15 of 31 |
| `\b[BGHJQZ]` | **ACCEPTED** | 7 of 31 |
| `q\|z\|b\|g\|h\|j` | **ACCEPTED** | 15 of 31 |

For contrast, the five patterns the author had in mind are correctly rejected:
`''`, `.`, `.{0}`, `a|`, `()`, `Canon|.*`, `win`, `store`, `system`.

### Is the canary approach sound at all? — Honest assessment: no, not as a bound.

The canary is a fixed five-element spot-check. It can only detect a pattern that happens
to hit one of those five literal strings. It is not a bound on how much gets deleted; it
is a unit test with five cases, embedded in the parameter block and presented as a
safety control. A pattern that matches Canon *and* every HP driver passes it trivially —
I demonstrated exactly that.

It is not worthless: the realistic fat-finger cases (`''`, `.`, `.*`, `*` → invalid regex)
are all caught, and it is strictly better than the unvalidated original. But
`FINAL-VERDICT.md:32` presents it as the fix that closed a CRITICAL delete-everything
defect, and the evidence offered ("8 dangerous patterns rejected") is a test of twelve
inputs the author chose, not a test of the guard's boundary. The boundary is one line of
regex away.

**The control that would actually bound the blast radius** is a count gate on the
*result*, not a shape check on the *pattern*: after `Get-VendorDriverPackage`, if the
match selects more than N packages, or more than one distinct `ProviderName`, stop and
require explicit confirmation or `-Force`. That is the only check that scales with what
the operator actually typed. Optionally pair it with rejecting regex metacharacters
outright (`^[A-Za-z0-9 .,&-]{3,}$`), which would kill every bypass above including the
single letters.

### Sub-checks on the same block — these are fine

- **`throw` inside `ValidateScript` surfaces correctly.** Executed: the message appears
  verbatim, prefixed `Cannot validate argument on parameter 'Vendor'.` Nothing is
  swallowed. Validation runs at parameter-binding time, i.e. *before* the script body,
  so the `try{}` at `:1032` is irrelevant to it.
- **PS 5.1:** a thrown exception in `ValidateScript` is a binding failure there too, so
  rejection is certain. Only the wording of the surfaced message is unverified (no 5.1
  runtime available).
- **Case tricks / `(?i)` / unicode:** no additional bypass beyond the above; `-match`
  is already case-insensitive, so `(?i)[bghjqz]` behaves identically to `[bghjqz]`.

---

## C2 — HIGH — `RESTORE.md` is missing on the run that installs the block

**File:** `windows/scripts/fix-stuck-driver-update.ps1:1047-1071`, `:1128`, `:1140`;
`docs/05-troubleshooting.md:111`
**Status: CONFIRMED BY INSPECTION** (call-graph is unambiguous; `Save-RestoreNote`
appears exactly once as a call, at `:1066`).

`Save-RestoreNote` is called **only** inside the third branch of the Phase 2/3 selector —
the branch that requires `-not $SkipDriverPurge` **and** `$packages.Count -gt 0`. Neither
of the other two branches writes it.

But the summary block at `:1140` prints, unconditionally on `$Execute`:

```
  How to undo everything: $runDir\RESTORE.md
```

and the `-BlockByHardwareId` branch at `:1128` also points the operator at `RESTORE.md`.

The trigger is not exotic — it is the script's own recommended workflow. `:1132` tells
the operator to run:

```
.\fix-stuck-driver-update.ps1 -Vendor Canon -Execute -SkipDriverPurge -SkipUpdateReset -BlockByHardwareId
```

(the same command as `FINAL-VERDICT.md` step 6). That run takes the `-SkipDriverPurge`
branch, writes **no** `RESTORE.md`, then tells the operator to go read a file that does
not exist.

This is the worst possible placement of the gap. The deny-list block is the single
hardest change to diagnose after the fact: it silently prevents the vendor's own driver
from installing, with no error the user can attribute to this script. That is exactly the
run with no undo guide.

`docs/05-troubleshooting.md:111` states "Each `-Execute` run writes a `RESTORE.md`".
That is false as written.

**Fix:** hoist the `Save-RestoreNote` call to just after the transcript starts, so every
`-Execute` run gets one; it already handles empty `$Package` and `$Printer` arrays
correctly (`:775`, `:791`).

---

## C3 — MEDIUM — `Test-PolicySupport` fails open on localised Windows

**File:** `windows/scripts/fix-stuck-driver-update.ps1:838`
**Status: CONFIRMED** — behaviour by inspection, remedy by primary source.

```powershell
if ($edition -match 'Home') { ...warn... }
```

`Win32_OperatingSystem.Caption` is a **localised** string. On a French Home installation
the caption reads *Famille*, not *Home*; other locales substitute their own word
(Chinese uses 家庭版). Those users take the `return $true` path: no warning, the registry
writes proceed, and the operator is left believing the block is effective when Windows
will silently ignore it.

This is the dangerous direction of the error. A Pro user spuriously warned loses nothing;
a Home user *not* warned is exactly the failure mode the check was added to prevent
(`FINAL-VERDICT.md:46`).

**Locale-proof alternative, confirmed from Microsoft's `Win32_OperatingSystem` page:**
the `OperatingSystemSKU` property (`uint32`) is numeric and locale-independent —
`PRODUCT_CORE` **(101)** is documented there as "Windows Home", and `PRODUCT_CORE_ARM`
is **(97)**. That page's enum predates the rest of the Home family; the remaining Home
SKUs (`PRODUCT_CORE_N` 98, `PRODUCT_CORE_COUNTRYSPECIFIC` 99,
`PRODUCT_CORE_SINGLELANGUAGE` 100) need confirming against the `GetProductInfo` page
before being hard-coded. Keep the caption check as a secondary signal; make the SKU the
primary one.

Minor, same line: `'Home'` is being used as a regex via `-match`. Harmless with this
literal, but `-like '*Home*'` states the intent.

---

## C4 — MEDIUM — the `-Verify` history check is permanently dead, not skipped once

**File:** `windows/scripts/fix-stuck-driver-update.ps1:924-930`
**Status: CONFIRMED BY EXECUTION** (wildcard semantics tested against real directories).

```powershell
$historyReset = @(Get-ChildItem -Path "$env:SystemRoot\SoftwareDistribution.old.*" `
    -Directory -ErrorAction SilentlyContinue).Count -gt 0
```

The script itself creates `SoftwareDistribution.old.<stamp>` on every `-Execute`
(`:585`), and **never removes it**. `RESTORE.md` tells the operator the old folders "can
simply be deleted once the machine is behaving" — i.e. cleanup is manual and optional,
and most operators will never do it.

Consequence: after the first successful `-Execute`, **every subsequent `-Verify` on that
machine reports SKIP forever**, including runs weeks later investigating an unrelated
recurrence. The fix traded a false PASS for a permanent blind spot. `FINAL-VERDICT.md:42`
describes this as detecting "the reset", which reads as a one-run condition; it is not.

**On the scenario raised in the brief** (a previous unrelated tool leaving a
`SoftwareDistribution.old`): I tested this and it mostly does **not** trigger. The
classic copy-paste Windows fix renames the folder to exactly `SoftwareDistribution.old`,
with no trailing segment, and PowerShell's `SoftwareDistribution.old.*` wildcard requires
the second dot — verified against three real directories, only the timestamped one
matched. So the false-skip source is the script's own artifact, not third-party debris.

**Fix:** compare the newest `.old.*` folder's timestamp against `$baseline.Data.TakenAt`
and only SKIP when the reset is newer than the baseline. That makes the skip
self-clearing on the next fresh `-Execute` cycle instead of permanent.

---

## C5 — LOW — `RESTORE.md` emits unescaped single quotes

**File:** `windows/scripts/fix-stuck-driver-update.ps1:800`, `:804` (and `:780`/`:782`)
**Status: CONFIRMED BY EXECUTION** (generated the line and parsed it with
`[scriptblock]::Create`).

```powershell
$lines += "Add-Printer -Name '$($p.Name)' -DriverName '$($p.DriverName)' -PortName '$($p.PortName)'"
```

A printer named `Bob's Printer` — an entirely ordinary name — produces:

```powershell
Add-Printer -Name 'Bob's Printer' -DriverName 'Canon TR8500 series' -PortName 'WSD-1'
```

which does not mean what it looks like. With a crafted port name the emitted line parses
as a command chain; I confirmed `…-PortName 'WSD-1'; Remove-Item C:\ -Recurse -Force #'`
parses cleanly as PowerShell.

Realistic severity is **broken copy-paste**, not RCE: the injection case needs a hostile
printer or port name, and the file is a document the operator reads before running. But
`RESTORE.md` is the undo path, it is written under the heading "Run every command from an
**elevated** PowerShell", and an apostrophe in a printer name is common enough to expect.

**Fix:** `$($p.Name.Replace("'","''"))` on each interpolation, including `$dir` at `:780`.

---

## C6 — LOW — unguarded `[int]` cast aborts mid-registry-write

**File:** `windows/scripts/fix-stuck-driver-update.ps1:688`
**Status: CONFIRMED BY EXECUTION.**

```powershell
$usedIndex += @($numbered | ForEach-Object { [int]$_.Name })
```

`[int]'2147483648'` and `[int]'999999999999'` both throw (verified). Both value names
match `^\d+$`, so the filter passes them straight to the cast. With the script's global
`$ErrorActionPreference = 'Stop'` and no surrounding try/catch, that terminates the run
**after** `DenyDeviceIDs=1` and `DenyDeviceIDsRetroactive=1` have already been written
(`:678-679`) but **before** any hardware ID is appended — leaving retroactive deny armed
over whatever list was already there.

The trigger is contrived (no sane admin names a registry value `2147483648`), which is
why this is LOW and not higher. Fix: `[int64]`, or wrap the cast and skip unparseable
names.

**The rest of this fix I attacked and it held** (all executed):

- `'01'` → 1, `'007'` → 7 — correct.
- `'+1'`, `'1e3'` — correctly filtered out by `^\d+$`.
- `Measure-Object -Maximum` over `@(0) + @(1,2,5)` → **5**; over `@(0)` alone → **0**.
  The 1,2,5 overwrite bug (F4/S6) is genuinely fixed.
- `Get-ItemProperty`'s pseudo-properties (`PSPath`, `PSParentPath`, `PSChildName`,
  `PSDrive`, `PSProvider`) cannot match `^\d+$` — the filter sees only real value names.
  Inspection only; the registry provider does not exist on macOS.
- `$existing` still collects `.Value` (the hardware-ID strings), not `.Name`, so the
  `-contains` dedup at `:696` is correct.

---

## C7 — LOW — the narrowed package match has no fail-loud path

**File:** `windows/scripts/fix-stuck-driver-update.ps1:239-241`
**Status: INSPECTION ONLY.**

The filter went from `ProviderName -match X **-or** OriginalFileName -match X` to
`ProviderName -match X **-and** Driver -like 'oem*.inf'` — one fewer property, and an
AND where there was an OR. If either property name is wrong or blank on the
`BasicDriverObject`, the result is zero packages and the script prints, in **green**:

```
   No driver-store packages match 'Canon'.
```

indistinguishable from a clean machine. The operator concludes the vendor has no stale
packages and moves on.

I am **not** claiming the property names are wrong. Dropping `-All` is confirmed correct
from Microsoft's own page — *"If you do not specify this parameter, only third-party
drivers are listed"* — which also makes the `oem*.inf` guard redundant rather than
harmful. And the `Get-WindowsDriver -Online | Select-Object Driver, OriginalFileName,
ProviderName, Version, Date` shape is a widely-reproduced third-party idiom, so
`ProviderName` and `Driver` almost certainly exist on the basic object. Microsoft
documents only the opaque output type, which is why `FINAL-VERDICT.md:66` already lists
this as assumed.

The point is narrower: this branch now has **two** ways to silently yield zero and
**zero** ways to say "I could not read the driver list." A one-line guard — warn if
`Get-WindowsDriver -Online` returned rows but the filter matched none, and if the first
row's `ProviderName` is null — converts a silent no-op into a visible one.

---

## Fixes I attacked and could not break

Stated plainly, because a real verification is worth more than a manufactured finding.

**Write-Status / transcript (F5, W4, W-2) — SOUND. Confirmed by execution.**
- Re-ran PSScriptAnalyzer **1.25.0** across the entire repo, recursively:
  **0 findings total, 0 for `PSAvoidUsingWriteHost`.** The suppression attribute is
  genuinely honoured; I did not take the prior claim on trust.
- Byte-copied the **shipped** helper (`:131-146`) into a real `.ps1` file, ran it under
  `Start-Transcript`, and confirmed both markers land in the log:
  plain `Write-Status 'X'` → **captured**, coloured `Write-Status 'X' 'Cyan'` → **captured**.
- All 7 files carry byte-identical helpers, and I verified all 7 genuinely call
  `Start-Transcript` — the justification text is accurate in every file, not copy-paste
  fiction inherited from the driver script.
- `grep`: zero `RawUI` references remain repo-wide.

**Empty / invalid `$Color` — no reachable path. Confirmed by execution.**
`Write-Host -ForegroundColor ''` *does* throw (`ParameterBindingException`, "Cannot
convert value \"\" to type System.ConsoleColor"), and so does an invalid colour name.
But the helper's `[string]::IsNullOrEmpty($Color)` guard takes the uncoloured branch
first. I grepped every call site across all 7 files: every colour argument is a string
literal. The only calls with a variable argument (`Write-Status $_.Exception.Message`,
`Write-Status $errText`) pass **one** argument, leaving `$Color` at its `''` default.
No caller can reach the throw.

**Date-based dedup (F3) — SOUND on PowerShell 7. Confirmed by execution.**
Real `ConvertTo-Json` → `ConvertFrom-Json` round-trip of the diagnosis object, tested at
all three `DateTimeKind` values:

| Kind | JSON | baseline key == live key |
|---|---|---|
| Utc | `"2026-08-30T17:42:11Z"` | **match** |
| Local | `"2026-08-30T17:42:11-07:00"` | **match** |
| Unspecified | `"2026-08-30T17:42:11"` | **match** |

`ConvertFrom-Json` returns a real `System.DateTime` preserving Kind, so `[datetime]$_.Date`
is a no-op cast and `.ToString('o')` produces identical strings on both sides. This was
the most likely place for the fix to be broken and it is not broken.

**Service `try/finally` (S3) — SOUND. Confirmed by inspection.**
The `finally` block cannot itself throw and mask the original error: every statement in
it is either a `Write-Status` (a `Write-Host` wrapper, which cannot throw given the
literal colours) or a `Start-Service` inside its own `try/catch`. A service deleted
mid-run makes `Start-Service -ErrorAction Stop` throw → caught → warning plus
"START IT MANUALLY". `$wasRunning.ContainsKey($svc)` on a hashtable cannot throw. The
only escape is process termination, which no `finally` survives.

**Backup verification (S4) — SOUND.** Requires exit 0 **and** ≥1 file **and** >0 total
bytes **and** ≥1 `.inf`, and `$exported -ne $Package.Count` aborts with exit 2 before any
deletion. The `exit 2` sits inside the outer `try{}`, and PowerShell runs `finally` on
`exit`, so the transcript still closes.

**Dry-run purity (D1) — HOLDS. Re-verified from scratch on the current file.**
I parsed `fix-stuck-driver-update.ps1` with the PowerShell AST and enumerated **all 30**
mutating command sites (`New-Item`, `Set-Content`, `Set-ItemProperty`, `Remove-Item*`,
`Rename-Item`, `*-Service`, `Remove-Printer*`, `Start-Transcript`, `pnputil`, `reg.exe`,
`dism.exe`, `sfc.exe`, `Get-WindowsUpdateLog`). Every one is either lexically inside
`if ($Execute)` or inside a function that opens with `if (-not $Execute) { return }`:

| function | guard |
|---|---|
| `Save-Diagnosis` | called under `if ($Execute)` at `:1039` |
| `Export-VendorDriver` | early return `:398` |
| `Reset-UpdateComponent` | early return `:556` |
| `Disable-DriverUpdate` | early return `:622` |
| `Disable-DeviceInstall` | early return `:663` |
| `Invoke-ImageRepair` | early return `:718` |
| `Save-RestoreNote` | called under `if ($Execute)` at `:1065` |
| `Save-UpdateLog` | called under `if ($Execute -and …)` at `:1110` |

Nothing mutates without `-Execute`. The three functions added by the fix are clean:
`Test-PolicySupport` does one `Get-CimInstance` and nothing else; `Get-VendorPrinter` is
a `Get-Printer` read; `Save-RestoreNote` writes but is `$Execute`-gated.

**Ordering — correct.** `Get-VendorPrinter` is called from `Get-Diagnosis` (`:306`), which
runs in Phase 1 on **both** the dry-run and `-Execute` paths. So `$diagnosis.Printer` is
populated well before `Save-RestoreNote` reads it at `:1066`, and before
`Remove-VendorDriver` deletes the queues at `:1070`. The undo guide is written from a
pre-purge snapshot, which is what it needs.

**Regression sweep `b7cec8d` → `dadd2cb` — clean.** The driver-script diff contains only
the 14 named fixes plus three new functions (`Get-VendorPrinter`, `Save-RestoreNote`,
`Test-PolicySupport`). No unrelated behaviour changed. No variable is read before
assignment — `$usedIndex`, `$wasRunning`, `$exportCode`, `$removeCode`, `$existing` are
all initialised before first use. The other six files' diffs are the identical 16-line
`Write-Status` swap and nothing else.

---

## Could not verify — stated as unknown, not as pass

**1. `SuppressMessageAttribute` on Windows PowerShell 5.1. UNVERIFIED.**
No 5.1 runtime exists on macOS, so I could not test it, and I will not assert it.

What I can say: it is a plain .NET attribute (`SuppressMessageAttribute` ships in the
.NET Framework, and its `Justification` property has existed since .NET Framework 4.0),
it is the exact syntax PSScriptAnalyzer's own documentation prescribes for decorating a
function, and PSScriptAnalyzer targets Windows PowerShell 5.1 as a first-class host. I
believe it parses. But `scripts/install.ps1:1` and `scripts/bootstrap/install.ps1:1` are
`#Requires -Version 5.1` fresh-machine bootstraps, and a parse error there is a **total**
bootstrap failure introduced by this fix — the exact severe regression the brief asked
about. The asymmetry justifies a 30-second test on any Windows box before trusting it:

```powershell
powershell.exe -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw scripts\bootstrap\install.ps1)) | Out-Null; 'PARSED OK'"
```

**2. `ConvertFrom-Json` date handling on Windows PowerShell 5.1. UNVERIFIED.**
The C4/F3 dedup key is proven correct on PowerShell 7 (above). Windows PowerShell 5.1
uses a different JSON deserializer. If 5.1 returns a `Local`-kind `DateTime` for a
UTC-serialised input, the baseline key and the live key diverge, **every** historical
failure is counted as new, and `-Verify` returns a false FAIL with exit 3. The script has
no `#Requires`, so it can be launched under either host. Settle it on the same Windows
box with:

```powershell
$d=[datetime]::new(2026,8,30,17,42,11,'Utc')
$j=([pscustomobject]@{Date=$d})|ConvertTo-Json; $b=($j|ConvertFrom-Json).Date
([datetime]$d).ToString('o') -eq ([datetime]$b).ToString('o')   # must be True
```

Both are cheap, both are decidable in one command, and both gate claims currently carried
as verified-adjacent in `FINAL-VERDICT.md`.

---

## Nit (no action required)

`Get-UpdateFailure` (`:209`) now keeps only ResultCode 4 and 5, but the `switch` at
`:214-220` still carries dead arms for 1 (`InProgress`) and 3 (`SucceededWithErrors`),
and `Show-Diagnosis:324` still labels the section "Non-successful update history" when it
now shows only Failed/Aborted. Cosmetic; the control flow is correct and matches the
Microsoft `OperationResultCode` enum.
