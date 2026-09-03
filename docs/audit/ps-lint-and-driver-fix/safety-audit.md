# Safety Audit — `windows/scripts/fix-stuck-driver-update.ps1`

> Read-only destructive-operations audit against the user's standing global safety
> rules. Written 2026-09-02. No repo file other than this one was modified, and no
> fix was implemented.
>
> **Method.** Every PowerShell/regex semantic claim below was executed on this Mac
> under `pwsh 7.6.5` and is marked **CONFIRMED** with its output. Windows-only
> cmdlet *behaviour* (`Stop-Service`, `pnputil`, PnP, spooler, Group Policy
> enforcement) cannot be executed here — `Get-Service`/`Stop-Service`/`Start-Service`/
> `Restart-Service` are all **absent** on this host (verified) — so those claims are
> marked **ASSUMED (documented)** and never as verified.

## Verdict

**NO-GO for `-Execute` in its current form on a daily-driver machine.**

The script's own guard rails (dry run by default, export-before-delete, rename-not-
delete, registry export before write) are real and well-intentioned. They are also
all *downstream* of a single unvalidated free-text regex that decides the entire
blast radius. The backup gate cannot save the user from an over-broad `-Vendor`,
because it verifies that the *matched* set was exported — not that the matched set
is the set the user meant.

Two CRITICAL findings, four HIGH, five MEDIUM, three LOW.

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| S1 | **CRITICAL** | `-Vendor ''` / `-Vendor '.'` matches every driver package; backup gate does not stop bulk delete | CONFIRMED (regex) / ASSUMED (pnputil) |
| S2 | **CRITICAL** | Same over-broad match feeds `DenyDeviceIDs` + `Retroactive=1` for every device on the machine | CONFIRMED (selection) / ASSUMED (GP effect) |
| S3 | **HIGH** | No `try/finally` around the service stop→start window; abort leaves 5 services stopped | CONFIRMED (control flow) |
| S4 | **HIGH** | Backup "verification" is presence-only; `pnputil` exit code never checked | CONFIRMED |
| S5 | **HIGH** | Restore guidance is incomplete, and is actively blocked by the block phase the script itself recommends | CONFIRMED (by inspection) |
| S6 | **HIGH** | `DenyDeviceIDs` numbering collides with and clobbers pre-existing entries (violates D7) | CONFIRMED (simulated) |
| S7 | MEDIUM | Printers and printer drivers are deleted with no backup and no snapshot record | CONFIRMED |
| S8 | MEDIUM | Phase 4 destroys the update history that `-Verify`'s "no new failures" check reads → guaranteed false PASS | CONFIRMED (by inspection) |
| S9 | MEDIUM | Malformed regex fails silently and is reported to the user in **green** as "no matches" | CONFIRMED (simulated) |
| S10 | MEDIUM | No confirmation in `-Execute`; the dry run is not a pinned contract for the execute run | CONFIRMED |
| S11 | MEDIUM | Prior service start-type/state is never captured; disabled services get started | CONFIRMED |
| S12 | LOW | `Restart-Service Spooler -Force` touches dependent services | ASSUMED (documented) |
| S13 | LOW | `reg export` failure is indistinguishable from "key does not exist" | CONFIRMED |
| S14 | LOW | Transcript + `diagnosis.json` capture username, machine name, and device serial numbers | CONFIRMED |

---

## S1 — CRITICAL: `-Vendor` is an unvalidated, unanchored regex that gates every deletion

**Where:** `fix-stuck-driver-update.ps1:89` (param), `:205`, `:220`, `:393`, `:415`,
`:445`, `:462`.

`$Vendor` is declared as a bare `[string]$Vendor = 'Canon'` with **no validation
attribute** (confirmed: no `ValidateNotNullOrEmpty`, `ValidatePattern`,
`ValidateScript`; no `[Regex]::Escape`; no `-SimpleMatch`/`-like` anywhere in the
file). It is then used as a regex in five `-match` sites that between them select
everything the script deletes:

| Site | Line | What the match selects | What is then done to it |
|------|------|------------------------|-------------------------|
| `Get-VendorDriverPackage` | 205 | `ProviderName` **or** `OriginalFileName` of `Get-WindowsDriver -Online -All` | `pnputil /delete-driver … /uninstall /force` (line 449) |
| `Get-VendorDevice` | 220 | `FriendlyName` **or** `InstanceId` of every PnP device | ghosts → `pnputil /remove-device` (468); all → hardware IDs → deny list (860) |
| printers | 393 | `Get-Printer` `DriverName` | `Remove-Printer` (403) |
| printer drivers | 415 | `Get-PrinterDriver` `Name` | `Remove-PrinterDriver -RemoveFromDriverStore` (430) |
| update history | 177 | `Title` | read-only |

### Confirmed regex behaviour (pwsh 7.6.5 on this host)

```
'anything' -match ''      => True
''         -match ''      => True
$null      -match ''      => True
'Realtek'  -match '.'     => True
'oem42.inf' -match '.'    => True
```

An empty pattern matches **everything, including `$null`**. `'.'` matches every
non-empty string. Both are silently accepted by the parameter.

### The realistic trigger is not a typo — it is `$null`

```
$v = $null; & ./script.ps1 -Vendor $v
  → Vendor bound to: '[]'  IsNullOrEmpty=True
  → matches: 5/5
```

PowerShell coerces `$null` to `''` when binding to `[string]`, and an explicitly
bound `''` **overrides the `'Canon'` default without any error**. Any wrapper, alias,
scheduled task, or copy-pasted snippet that passes an unset variable (`-Vendor $vendor`,
`-Vendor $env:VENDOR`) silently arms whole-system mode. This is the single most
likely path to the catastrophic outcome, and it produces no warning of any kind.

### Scenario

`.\fix-stuck-driver-update.ps1 -Vendor $unset -Execute`

1. `Get-WindowsDriver -Online -All` returns every driver package on the machine
   (with `-All`, inbox packages as well as third-party OEM ones). `-match ''`
   selects all of them.
2. Phase 2 exports each one. Exports succeed → `$exported -eq $Package.Count` →
   **the backup gate passes.** The gate checks that the matched set was backed up.
   It has no notion of "this set is implausibly large".
3. Phase 3 runs `pnputil /delete-driver <pkg> /uninstall /force` against every one.
   ASSUMED: inbox packages fail (non-`oemNN.inf` published names, protected) and
   only produce warnings; every **third-party OEM package** — GPU, NIC, Wi-Fi,
   chipset, storage controller, audio, Bluetooth, touchpad — is deleted, and
   `/force` removes packages that are currently bound to live devices.
4. Every printer and printer driver on the system is removed (lines 399–442).

Losing the storage-controller or NIC package on a daily driver is a
non-boot / no-network outcome recoverable only from the export folder — which is
itself on the machine that no longer boots.

**There is no pause, `Read-Host`, or count cap anywhere in the script** (confirmed
by inspection): the only thing standing between the user and step 3 is that
`Show-Diagnosis` printed several hundred lines they were expected to read as they
scrolled past.

### Other metacharacter cases (all confirmed)

| Input | Result | Consequence |
|-------|--------|-------------|
| `-Vendor '*'` | `RegexParseException: Quantifier '*' following nothing` | Throws inside each `try` → **fails silent**, see S9 |
| `-Vendor 'C:\Canon'` | `Unrecognized escape sequence \C` | Same |
| `-Vendor 'C++'` | `Nested quantifier '+'` | Same |
| `-Vendor 'HP [LaserJet'` | `Unterminated [] set` | Same |
| `-Vendor 'Intel(R)'` | `'Intel(R) Corp' -match 'Intel(R)'` → **False**; `'IntelR'` → True | Silent false-negative; user believes nothing matched |
| `-Vendor 'NVIDIA*'` (glob habit) | `'NVIDI' -match 'NVIDIA*'` → True | Broader than intended |
| `-Vendor 'Brother [MFC]'` | matches `Brother M`, `Brother F`, `Brother C` | Broader than intended |

The default `'Canon'` is benign — it is a distinctive multi-character literal with no
metacharacters. Every finding here is about what happens the moment the user takes
the `.PARAMETER Vendor` doc ("Case-insensitive regex") at its word, or passes a
variable.

**Mitigation (recommend, not implemented):**
1. `[ValidateNotNullOrEmpty()]` + `[ValidateLength(3,64)]` + reject any input whose
   escaped form differs from itself unless an explicit `-VendorIsRegex` switch is
   passed; default to literal matching via `-match [Regex]::Escape($Vendor)` or
   `.Contains($Vendor, 'OrdinalIgnoreCase')`.
2. Wrap each `-match` in a pre-flight `[regex]::new($Vendor)` inside a `try` at
   startup and **exit 1** on a parse failure, rather than letting five separate
   `catch` blocks swallow it.
3. Hard blast-radius cap: if `$packages.Count -gt 5` (or `> 25%` of all packages),
   abort with a non-zero exit and require an explicit `-IAcknowledgeBlastRadius`
   plus a re-typed count. Canary-before-bulk is the user's standing rule.
4. Never match `-Vendor` against a *path* (`OriginalFileName`) without anchoring to
   the filename component.

---

## S2 — CRITICAL: over-broad match writes `DenyDeviceIDsRetroactive=1` for every device

**Where:** `:248` → `:257` (`HardwareId` built from **all** matched devices, not just
ghosts) → `:860` → `Disable-DeviceInstall` `:594–615`.

`Get-VendorHardwareId` is fed `$devices` — every device matching `$Vendor` on
`FriendlyName` **or** `InstanceId`, in any state. Healthy, in-use devices are
included. Their hardware IDs are written into `…\DeviceInstall\Restrictions\DenyDeviceIDs`
alongside `DenyDeviceIDs=1` and `DenyDeviceIDsRetroactive=1`.

Retroactive is exactly the setting whose purpose is to apply the block to
**already-installed** devices. Combined with S1's empty/`.` pattern, one `-Execute
-BlockByHardwareId` run denies installation of every hardware ID on the machine.
ASSUMED (documented, not executable here): the practical effect surfaces on the next
boot or PnP re-enumeration, at which point recovery requires Safe Mode or offline
registry editing — from a machine whose storage/NIC drivers were also just deleted by
S1. The two findings compound.

Note the sibling audit (`windows-api-audit.md`, claim 9) already flags the
`DenyDeviceIDs` **subkey numbering format** as corroborated only by non-Microsoft
sources. The key path and the two DWORD names are officially confirmed; the list
storage is ASSUMED. That uncertainty is upstream of S6 as well.

**Even at the intended scope this deserves a louder warning.** With `-Vendor Canon`,
a user with a working Canon scanner or camera *and* a broken Canon printer gets the
scanner's hardware IDs denied too. The dry run does print `would: deny hardware ID <id>`
per ID (line 577), which is honest — but a raw `USB\VID_04A9&PID_1793` string is not
something a user can map back to "my scanner".

**Mitigation:** restrict `$HardwareId` to the IDs of devices actually purged (ghosts /
the specific failing device), not every match; print the owning device's
`FriendlyName` next to each ID in the plan; make `DenyDeviceIDsRetroactive` a separate
opt-in switch (`-BlockRetroactive`) that defaults **off**, since a forward-only block
solves the stated problem — stopping *redelivery* — without touching installed hardware.

---

## S3 — HIGH: no `try/finally` guarantees the five services restart

**Where:** `Reset-UpdateComponent` `:475–526`.

Services stopped: `wuauserv`, `bits`, `cryptsvc`, `msiserver`, `usosvc`.

**CONFIRMED by inspection and by control-flow simulation:** the stop loop (491–500),
the `Start-Sleep 3` (502), the rename loop (504–514) and the start loop (516–525) are
four sequential `foreach`es in the function body. There is **no** `try/finally`
wrapping the stop→start window. The only `finally` in the file is at `:912`, and it
does exactly one thing — `Stop-Transcript`. It does not restart services.

Simulation output:

```
   stopped wuauserv / bits / cryptsvc
   [error thrown before the start loop]
   finally: Stop-Transcript ran
   service state after abort: cryptsvc=stopped, bits=stopped, wuauserv=stopped
```

Anything that raises a terminating error inside that window leaves all five services
stopped. `$ErrorActionPreference = 'Stop'` is in force at file scope (`:100`), so this
is not exotic — the inner `try/catch`es only cover `Stop-Service`, `Rename-Item` and
`Start-Service` themselves. `Split-Path`, `Test-Path`, `Get-Service` and `Get-Date`
failures, a `CTRL+C`, a console close, or an OOM all escape. **`CTRL+C` is the most
likely one in practice**, because Phase 4 is where a user who has just watched Phase 3
delete more than they expected will reach for it.

### Consequences of `cryptsvc` staying down

ASSUMED (documented; not executable on macOS). CryptSvc provides the Catalog Database
(signature verification for Windows files and drivers), Protected Root, Automatic Root
Certificate Update and Key services. With it stopped:

- driver and catalog signature validation fails → further driver installs fail,
- MSI installs and Windows Update fail,
- certificate chain building for services that use the system store degrades
  (some VPN / 802.1X EAP-TLS paths),
- `sfc` / `DISM` verification behaves unpredictably.

`msiserver` down blocks all MSI installers. `bits` down blocks background transfers.

Stopping CryptSvc is *itself* standard practice — it is required to rename `catroot2`,
and it is part of Microsoft's own documented Windows Update reset procedure. The
defect is not that the script stops it; it is that the script does not **guarantee**
it starts again.

### Recovery if the script dies mid-phase

A reboot restores all five (they are `Automatic`/`Manual`/trigger-start; none are
disabled by the script). The problem is that the user is not told this. The abort
path prints nothing about services, and the folder-rename failure branch (`:512`)
tells the user to "reboot and re-run with `-SkipDriverPurge`" — good advice by
accident, but it only fires for the *caught* rename failure, not for the escape path.

Also **ASSUMED (documented):** `Stop-Service -Force` stops the target's *dependent*
services as well, while `Start-Service` starts only the services the target
*depends on* — not its dependents. So even on the happy path, any service that
depends on `cryptsvc`, `bits` or `msiserver` is stopped by the `-Force` on line 495
and is **never restarted** by lines 516–525. It stays down until reboot. Additionally,
`usosvc` (Update Orchestrator) is commonly not stoppable even from an elevated session
on Windows 10/11 — expect a warning there, followed by a `SoftwareDistribution` rename
failure because a service still holds it.

**Mitigation:** wrap 491–525 in `try { … } finally { <start loop> }`; capture each
service's `StartType` and `Status` *before* stopping and restore both; enumerate
`(Get-Service $svc).DependentServices` before the `-Force` stop and restart those
explicitly; on the escape path print "SERVICES ARE STOPPED — reboot now" in red.

---

## S4 — HIGH: the backup "verification" is presence-only

**Where:** `Export-VendorDriver` `:355–380`.

```powershell
& pnputil.exe /export-driver $pkg.Driver $target 2>&1 | Out-Null
$files = Get-ChildItem -Path $target -Recurse -File -ErrorAction SilentlyContinue
if ($files -and $files.Count -gt 0) { $exported++ }
```

**CONFIRMED:** a directory containing a single 1-byte file passes the gate.

```
files found: 1 -> gate '$files -and $files.Count -gt 0' = True   <-- counts as VERIFIED backup
```

Three gaps against the user's rule ("VERIFY the backup exists **and is readable** —
`ls -lh` AND test integrity"):

1. **`$LASTEXITCODE` from `pnputil /export-driver` is never read.** Contrast line 450,
   where the *delete* path does capture it. Output is `2>&1 | Out-Null` — discarded.
   A failed export that still created the target directory and dropped one file is
   indistinguishable from success.
2. **No size, hash, or file-list comparison against the source package.** A driver
   package is an INF plus `.sys`/`.cat`/`.dll`/`.gpd` payload. An export that lands
   only `cnp60.inf` — disk full, ACL denial, path-length truncation — passes. The
   `.cat` in particular is what makes the package re-installable; without it,
   `/add-driver /install` will fail signature validation.
3. **No check that an `.inf` is present at all.** A single stray file of any kind
   satisfies the gate, which matters because the restore path (S5) is keyed on an INF.

One thing the script gets *right*: `$target` lives under a per-run timestamped
`$runDir` (`:802–803`, `:835`), so stale files from a previous run cannot fool the
count. Worth preserving.

**Mitigation:** check `$LASTEXITCODE -eq 0`; require at least one `*.inf` **and** the
package's `.cat`; record each file's length and SHA-256 into a `manifest.json` beside
the export; re-read one file to prove readability; compare the exported file count
against `Get-WindowsDriverFile`/the package's own file list where available. Abort on
any mismatch — the existing `exit 2` path is the right shape, it is just fed by a
check that is too weak.

---

## S5 — HIGH: the restore path is incomplete and is blocked by the script's own recommendation

**Where:** `:902` — `Restore a driver: pnputil /add-driver <path-to-inf> /install`.
Also `docs/05-troubleshooting.md:85–86`.

Four problems, all CONFIRMED by inspection:

1. **The block phase blocks the restore.** The dry-run summary tells the user to run
   `-Execute -BlockByHardwareId` (`:909`), and `docs/05-troubleshooting.md:79` shows
   exactly that as *the* apply command. That run writes `DenyDeviceIDs` +
   `Retroactive=1` for the device's hardware IDs. `pnputil /add-driver … /install`
   binds the driver to a device — which the deny list now forbids. The restore line
   does **not** mention that the deny entry must be removed first. The undo commands
   exist (`:619–620`) but appear ~280 lines earlier in the transcript, under Phase 5,
   and are never linked to the restore instruction.
2. **`<path-to-inf>` is not the path the user has.** Exports land in
   `$runDir\drivers\<driver-name-without-.inf>\`, one subdirectory per package,
   each containing the package tree. With multiple packages the user has several
   INFs and no guidance on which. The message shows a singular placeholder.
3. **Printers are not restorable this way at all.** `/add-driver` re-stages the
   package into the driver store; it does not re-register the spooler driver
   (`Add-PrinterDriver`) and does not recreate the print queue, port, or per-queue
   settings that `Remove-Printer` destroyed (see S7). A user following line 902 after
   a printer purge gets a staged package and still no printer.
4. **ASSUMED:** `/install` requires the target device to be present and enumerated.
   If the ghost device was removed in Phase 3 and the physical device is off/unplugged,
   the command stages but does not install, with no explanation offered.

**Mitigation:** write an actual `RESTORE.md` into `$runDir` at export time,
enumerating the exact per-package commands with real absolute paths, the deny-list
removal step that must precede them, and a separate section for re-adding printers
(with the `Get-Printer` snapshot from S7). "Here is one generic command" is not a
restore plan for a six-phase destructive script.

---

## S6 — HIGH: `DenyDeviceIDs` numbering collides with pre-existing entries (violates D7)

**Where:** `Disable-DeviceInstall` `:597–615`.

```powershell
$index = $existing.Count
foreach ($id in $HardwareId) { … $index++; Set-ItemProperty -Path $denyKey -Name "$index" -Value $id … }
```

The append logic assumes value names are contiguous and 1-based. **CONFIRMED by
simulation** that they need not be:

```
existing value names : 1, 2, 5      ($existing.Count = 3)
  writes value name '4' -> collides? False
  writes value name '5' -> collides? True   (clobbers 'USB\VID_CORP&PID_BLOCKED')

gap case, names 1,3:
  writes '3' -> collides? True   (clobbers the existing entry)
```

Non-contiguous names are exactly what corporate Group Policy tooling, MDM, or a
previous partial cleanup produces. `Set-ItemProperty` overwrites silently — no error,
and the script prints `denied <id>` in **green** for a write that just destroyed
someone else's block. An IT-mandated device block is silently lifted.

This directly violates invariant **D7** ("never clobbers entries it did not create").

Partially mitigated: `reg export` of the `Restrictions` key runs first (`:583`), so
the clobbered value is recoverable from `DeviceInstall-policy.reg` — *if* the user
knows to look, and if the export actually succeeded (see S13).

Note also that this whole mechanism rests on the numbering format the sibling
`windows-api-audit.md` rates as corroborated only by non-Microsoft sources.

**Mitigation:** compute `$index` as `max(existing numeric names) + 1`, not `count`;
before each write, assert the target name does not already exist and abort if it does;
prefer a GUID-suffixed or otherwise non-colliding naming scheme if the ADMX format
permits; verify the format on a real machine before relying on it.

---

## S7 — MEDIUM: printers and printer drivers are deleted with no backup and no record

**Where:** `:399–442`; `Get-Diagnosis` `:249–258`.

`Remove-Printer` and `Remove-PrinterDriver -RemoveFromDriverStore` delete every
match. **CONFIRMED:** the `diagnosis.json` snapshot contains `RebootFlag`,
`UpdateFailure`, `DriverPackage`, `Device`, `HardwareId` — **no printer data at all**.
Nothing captures printer names, port configuration, share names, default-printer
status, driver names, or per-queue preferences (paper size, duplex, colour profile,
tray mapping). The only trace is prose in `run.log`, and only when `-Execute` is set
(the dry run is not transcribed at all — see S10).

For a network printer with a static TCP/IP port and tuned defaults, this is real,
non-obvious rework. `docs/05-troubleshooting.md:85` says "The script backs up every
driver package it touches (and verifies the backup landed) before deleting anything"
— accurate about *driver packages*, and the user will reasonably read it as covering
the printer that the script also deletes.

The user's rule is "take a backup/snapshot before modifying infrastructure", not
"before deleting driver packages specifically".

**Mitigation:** add `Printer = @(Get-Printer | Select-Object *)` and
`PrinterDriver`/`PrinterPort` to `Get-Diagnosis`; write them into `diagnosis.json`
before Phase 3; export per-queue settings via `Get-PrintConfiguration`; reference the
snapshot from the restore guidance.

---

## S8 — MEDIUM: Phase 4 destroys the evidence `-Verify` checks, guaranteeing a false PASS

**Where:** `Reset-UpdateComponent` `:477–480` (renames `SoftwareDistribution`) vs.
`Test-FixResult` `:720–732` and `Get-UpdateFailure` `:166–197`.

The "no new failed update attempts since the baseline" check reads Windows Update
history via `Microsoft.Update.Session` → `QueryHistory`. That history lives in
`SoftwareDistribution\DataStore`, which Phase 4 renames away. After a successful
Phase 4 + reboot, `GetTotalHistoryCount()` is ~0, so `$now.UpdateFailure` is empty,
so `$newFailures` is empty, so the check **always prints PASS** — including in the
case it exists to catch, where the driver was re-offered and failed again.

Two of the three `-Verify` checks remain meaningful (reboot flags, package presence).
The third is decorative and is reported to the user as a green PASS, which is worse
than not running it.

This also weakens invariant **D9**: the baseline-relative comparison was designed to
avoid false *failures*; the interaction with Phase 4 turns it into a guaranteed false
*success*.

**Mitigation:** have `-Verify` detect that `SoftwareDistribution` was reset (the
`.old.<stamp>` sibling is right there, and the run stamp is in `diagnosis.json`) and
report `SKIPPED — update history was reset by the fix, cannot compare` instead of
PASS; or read failures from the `Setup`/`WindowsUpdateClient` event logs, which
survive the rename.

---

## S9 — MEDIUM: a malformed `-Vendor` fails silently and is reported in green as "clean"

**Where:** `:207–210`, `:221–225`, `:193–195`, `:394–396`, `:416–418`.

Every `-match` site is inside a `try` whose `catch` calls `Write-Status`/`Write-Warn`
and returns the empty collection. `Write-Status` writes to the host and emits nothing
to the pipeline, so the caller sees a clean empty result. **CONFIRMED by simulation**
with the real helper shape:

```
bad pattern 'C:\Canon' -> count = 0    <-- then rendered as 'No driver-store packages match' in GREEN
good pattern 'Canon'   -> count = 1
```

So `-Vendor '*'`, `-Vendor 'C++'`, `-Vendor 'HP [LaserJet'` and friends all produce:

- `No driver-store packages match '<x>'.` in **green** (`:298`),
- `No failed update history matching '<x>'.` in **green** (`:287`),
- Phases 2 and 3 marked `[nothing to back up]` / `[nothing to purge]`,
- and the script proceeds anyway to **Phase 4** — stopping five services and renaming
  `SoftwareDistribution` and `catroot2`.

The user is shown a green all-clear for a query that crashed, and then a destructive
phase runs on the strength of it. Note `Get-VendorDriverPackage`'s catch does print a
yellow `(Get-WindowsDriver failed: …)` line — but it is one line above three green
ones, and it is worded as a cmdlet problem, not "your `-Vendor` argument is not a
valid regex".

**Mitigation:** validate the pattern once at startup (`[regex]::new($Vendor)` in a
`try`) and `exit 1` on failure, before anything else — the same slot as the
`-Execute`/`-Verify` guard at `:744`. A pattern that cannot compile is a bad-argument
condition, which the script already has an exit code for.

---

## S10 — MEDIUM: no confirmation in `-Execute`, and the dry run is not a contract

**Where:** whole script. **CONFIRMED:** no `SupportsShouldProcess`, no `ConfirmImpact`,
no `Read-Host`, no pause. `[CmdletBinding()]` is present but bare, so `-WhatIf` and
`-Confirm` are **not** available despite the script being a textbook candidate for
them.

Given S1 and S2, "the dry run was read" is not an adequate gate. Four specific gaps:

1. **Nothing is pinned.** `-Execute` re-enumerates from scratch (`:816`). The set
   deleted is whatever matches *at execute time*, not what the dry run displayed. A
   device plugged in between the two runs is in scope silently.
2. **The recommended command contains a flag the dry run never exercised.** The
   dry-run footer says `… -Execute -BlockByHardwareId` (`:909`) — but if the user's
   dry run omitted `-BlockByHardwareId` (as the docs' step 1 does,
   `05-troubleshooting.md:76`), Phase 5 printed `[SKIPPED]` and they have **never
   seen** the deny-list plan they are about to apply. The docs walk the user straight
   into this: step 1 without the flag, step 2 with it.
3. **The dry run is not recorded.** `Start-Transcript` only runs under `-Execute`
   (`:806–809`). There is no artifact to diff the execute run against.
4. **The backup gate is never rehearsed.** `Export-VendorDriver` returns `$true`
   unconditionally in dry run (`:347–350`), so the dry run gives no signal about
   whether the export would actually work.

**Mitigation (recommend, do not implement):**
- Add `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]` and wrap each
  destructive call in `$PSCmdlet.ShouldProcess(...)`; keep `-Execute` as the explicit
  arm but let `-Confirm`/`-WhatIf` work natively.
- Require typed confirmation in `-Execute` proportional to blast radius: print
  `N packages, M printers, K devices` and require the user to re-type `N` (or the
  vendor string) unless `-NonInteractive` is passed.
- Transcript the dry run too, and have `-Execute` accept
  `-FromPlan <path-to-dry-run-diagnosis.json>`, aborting if the live set differs from
  the plan. That turns the dry run into an actual contract.
- Have the dry-run footer echo back only the flags the user actually just dry-ran.
- Change `docs/05-troubleshooting.md` step 1 to include `-BlockByHardwareId` so the
  dry run covers every phase step 2 will execute.

---

## S11 — MEDIUM: prior service state is never captured

**Where:** `:491–525`.

The script stops five services and unconditionally starts all five at the end
(subject to `Get-Service` returning non-null). It never records what state or
`StartType` they were in beforehand.

If the user had deliberately disabled `wuauserv` or `usosvc` to suppress Windows
Update — a common configuration, and highly plausible for someone whose stated
problem is "Windows Update keeps nagging me" — the script re-starts it. `Start-Service`
on a `Disabled` service fails and produces a warning (so `StartType=Disabled` survives),
but a service that was merely *stopped* and `Manual` is left **running**. The user's
suppression is partially undone without being told.

**Mitigation:** snapshot `Status` + `StartType` per service into `diagnosis.json`
before Phase 4 and restore both, rather than blanket-starting.

---

## S12 — LOW: `Restart-Service Spooler -Force` reaches dependent services

**Where:** `:423`. ASSUMED (documented; not executable here). `-Force` is required
because the spooler holds driver locks, but it also acts on services dependent on
Spooler (classically the Fax service). Per the same documented asymmetry as S3,
dependents stopped by a `-Force` operation are not guaranteed to come back. Low
impact — Spooler dependents are rare on a desktop, and this is a restart rather than
a stop — but it is the same unguarded pattern.

**Mitigation:** enumerate and explicitly restore `DependentServices`, or use
`Stop-Service`/`Start-Service` with a `finally`.

---

## S13 — LOW: `reg export` failure is read as "the key does not exist"

**Where:** `:541–548` and `:583–589` (identical pattern).

```powershell
& reg.exe export $regPath $backup /y 2>&1 | Out-Null
if (Test-Path $backup) { "registry backed up" } else { "(no existing policy key to back up -- it will be created)" }
```

`$LASTEXITCODE` is discarded and stderr is nulled. Any failure — path typo,
insufficient rights on the policy hive, destination not writable, disk full — lands
in the `else` branch and is reported as the benign "key doesn't exist yet", after
which the script **writes to the registry anyway**. Invariant **D6** ("exported
before any value is written") is satisfied in form but not in substance: an
unverified export is treated as an absent key.

This is the same "a write command succeeding does not mean the file landed" failure
class as S4, and the same class the user's global rules call out by name — inverted
here (a *failed* command is read as a benign no-op).

**Mitigation:** check `$LASTEXITCODE`; distinguish exit 1 (key absent) from other
failures by probing `Test-Path $key` first; abort rather than write when the key
exists but the export did not land; verify the `.reg` is non-empty and readable.

---

## S14 — LOW: transcript and snapshot capture identifying data

**Where:** `:808–809` (`run.log`), `:821` (`diagnosis.json`), both under
`$env:USERPROFILE\dotfiles-backups\driver-fix\<stamp>\`.

**CONFIRMED** — `Start-Transcript` header on this host:

```
Username: Infinity\vijayg
RunAs User: Infinity\vijayg
Machine: Infinity (Unix 26.6.2)
Host Application: … -File t4.ps1
Process ID: 22958
```

On Windows this is `DOMAIN\username`, the machine name, and the full invocation.
`diagnosis.json` additionally contains `ComputerName` (`:252`), full device
`InstanceId`s and `HardwareId`s. **USB `InstanceId`s frequently embed the device's
serial number in the final segment** (e.g. `USB\VID_04A9&PID_1793\ABC123`), as do
`USBSTOR` entries — so the snapshot carries hardware serials for every matched device.
Printer names may include location or user names. `Get-WindowsUpdateLog` output
(`:658`, written only when warnings occurred) includes paths and update metadata.

Files sit in the user profile with inherited ACLs — appropriate for local use. The
risk is entirely downstream: this is a troubleshooting script, and the natural next
step for a stuck user is to paste `run.log` into a forum or GitHub issue.

**Mitigation:** note in the summary and in `docs/05-troubleshooting.md` that
`run.log`/`diagnosis.json` contain the machine name, username and device serial
numbers and should be redacted before sharing; optionally offer a `-Redact` switch
that masks the instance-ID tail.

---

## Irreversibility ranking (finding 7)

Ordered most to least irreversible, with what the user is actually told:

| Rank | Operation | Reversible? | Is the user told accurately? |
|------|-----------|-------------|------------------------------|
| 1 | `Remove-Printer` — queue, port, share, per-queue preferences | **No.** Nothing is captured anywhere (S7). Manual rebuild from memory. | **No.** Docs claim the script "backs up every driver package it touches … before deleting anything"; a user reads that as covering the printer. |
| 2 | `pnputil /delete-driver /uninstall /force` on an OEM package whose vendor no longer ships it | **Only** from the export — and only if the export was complete (S4) and the deny list is lifted first (S5). | **Partially.** The `pnputil /add-driver` line implies a clean restore; the caveats are absent. |
| 3 | `DenyDeviceIDs` numbering collision destroying a pre-existing entry | Recoverable from `DeviceInstall-policy.reg` **if** the export landed (S13) and the user knows to look. | **No.** Printed in green as a successful `denied <id>`. |
| 4 | `dism /restorehealth` + `sfc /scannow` replacing system files | No undo. Generally benign and idempotent. | Adequately: flagged as slow, opt-in only. |
| 5 | `SoftwareDistribution` rename — Windows Update **history** is lost | Folder is renamed, not deleted, so the data survives on disk; the live history is gone until rebuilt. | **Partially.** `:852` correctly says "renamed, not deleted"; nobody mentions the history loss, or that it silently disarms a `-Verify` check (S8). |
| 6 | `catroot2` rename — catalog cache | Rebuilt automatically by CryptSvc. | Yes. |
| 7 | `pnputil /remove-device` on a **ghost** device | Re-enumerated when the physical device returns. | Yes. |
| 8 | Registry policy writes (`ExcludeWUDriversInQualityUpdate`, `DenyDeviceIDs`) | Fully reversible; exact undo commands are printed (`:553–554`, `:618–620`). | **Yes — this is the best-handled area of the script.** |
| 9 | Service stop/start | Reboot restores. | **No.** The escape path (S3) prints nothing at all. |

The script's own framing — "Backs up and verifies before any delete" — is accurate
for exactly one of these nine rows (row 2, and only conditionally). Rows 1, 3 and 9
are the ones a user would most want warned about, and they are the three that are
silent or actively green.

---

## What this audit verified vs. left unchecked

**Verified by execution on this host (pwsh 7.6.5, macOS):**
regex semantics of `-match` for empty / `.` / metacharacter / malformed patterns;
`$null → ''` parameter coercion and default override; the fail-silent shape of the
`try`/`catch`/`Write-Status` idiom; `DenyDeviceIDs` index-collision arithmetic against
non-contiguous names; the presence-only backup gate against a 1-file directory;
`Start-Transcript` header contents; absence of validation attributes,
`SupportsShouldProcess`, `[Regex]::Escape`, `Read-Host` in the source.

**Verified by source inspection only:** control flow of the stop→rename→start window
and the single `finally`; the contents of `Get-Diagnosis` (no printer data); the
`Phase 4 → -Verify` interaction; the dry-run/execute divergence and the flags in the
docs' worked example.

**ASSUMED, not verified — no Windows machine available:** `pnputil` behaviour for
`/export-driver`, `/delete-driver /uninstall /force` and `/remove-device`; whether
inbox packages resist deletion; `Get-WindowsDriver -All` composition; Group Policy
enforcement of `DenyDeviceIDsRetroactive` on already-installed devices and its exact
timing; `Stop-Service -Force` dependent-service semantics and `Start-Service`'s
non-restoration of dependents; `usosvc` stoppability; CryptSvc's live dependent list
on Windows 11; the `DenyDeviceIDs` subkey numbering format (also flagged as
non-primary-sourced in `windows-api-audit.md`).

**Not examined at all (out of this audit's scope):** the other six `.ps1` files;
`Write-Status` conversion fidelity; the lint and rename changes; whether
`Microsoft.Update.Session` COM behaves as assumed; anything about the actual Canon
2.90.2.30 failure mode.

**What I still suspect could be wrong and would test first on real hardware:**
(a) whether `pnputil /delete-driver /force` on an in-use OEM package succeeds
immediately or defers to reboot — this changes S1 from "instant brick" to "brick on
next boot", which matters for recovery; (b) whether `DenyDeviceIDsRetroactive`
disables a running device or only blocks future installs — the difference between S2
being catastrophic and merely serious; (c) the real `DenyDeviceIDs` value-name format,
which S6 depends on entirely.
