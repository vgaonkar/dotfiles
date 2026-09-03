# Audit: `Write-Host` → `Write-Status` Conversion (Change 2)

**Scope:** invariants W1–W5, SPEC `docs/audit/ps-lint-and-driver-fix/SPEC.md`
**Method:** reconstructed pre-conversion files via `git show <commit>~1:<path>`, paired every
call site against the current tree, and ran runtime tests on pwsh 7.6.5 (macOS arm64) — the
only toolchain available. No Windows machine was available; anything about real-Windows-host
behavior is sourced from PowerShell's own public code, not executed live, and is labeled
accordingly.

## Summary of findings

| # | Finding | Severity | Status |
|---|---|---|---|
| 1 | `Write-Status` output is **not captured by `Start-Transcript`** in pwsh — violates W4 | **HIGH** | **CONFIRMED** (reproduced) |
| 2 | The coloured branch of `Write-Status` has **no exception handling** around `$Host.UI.RawUI.BackgroundColor`, unlike Microsoft's own `Write-Host` cmdlet, which wraps the identical read in `try/catch (HostException)` specifically for non-interactive hosts | **HIGH** (for `scripts/install.ps1` and `scripts/bootstrap/install.ps1`, both fresh-machine PS 5.1 bootstrap scripts) | **CONFIRMED** via primary source (PowerShell/PowerShell repo); not reproduced on a literal Windows 5.1 binary — none available |
| 3 | SPEC's stated "163 Write-Host calls across 7 files" does not reconcile with git history or the current tree; actual figure is 169 conversions across 6 files (a 7th file, `fix-stuck-driver-update.ps1`, was authored with `Write-Status` from birth and never contained `Write-Host`) | LOW (documentation accuracy only) | CONFIRMED |
| 4 | Message text, argument count, and colour on every converted call site | — | CONFIRMED: **zero mismatches** across all 169 conversions |
| 5 | Here-string preservation (W2) | — | CONFIRMED: exactly 4 preserved, correctly untouched, generated script is self-contained |
| 6 | All colour strings used anywhere in the repo are valid `[System.ConsoleColor]` members, including `Blue` | — | CONFIRMED |

---

## 1. Reconstruction and diff (W1, W5)

Reconstructed the pre-conversion version of all 6 files that actually contained `Write-Host`
(the SPEC lists 7 files with `Write-Status`, but `windows/scripts/fix-stuck-driver-update.ps1`
is a **new file added in the same commit** — `git show 259068c~1:windows/scripts/fix-stuck-driver-update.ps1`
returns "exists on disk, but not in `259068c~1`" — so it was written with `Write-Status` from
the start and has no pre-conversion `Write-Host` history. It is excluded from the pairing
exercise below because there is nothing to pair against.)

Extracted every `Write-Host <msg> [-ForegroundColor <c>]` from the reconstructed originals and
every `Write-Status <msg> [<c>]` from the current tree, paired them **in file order**, and
diffed message text + colour programmatically (not by sampling):

| File | Live-code pairs checked | Mismatches |
|---|---|---|
| `scripts/bootstrap/install.ps1` | 1 direct call (`Write-Host $errText` → `Write-Status $errText`) + 5 helper wrappers (`Write-Header`/`Write-Info`/`Write-Ok`/`Write-Warn`/`Write-Err`, each now delegating to `Write-Status` with the same literal colour it always used: Blue/Blue/Green/Yellow/Red) | 0 |
| `scripts/install.ps1` | 26 | 0 |
| `scripts/lint.ps1` | 7 | 0 |
| `windows/scripts/install-pwsh-tools.ps1` | 2 | 0 |
| `windows/scripts/install-wezterm.ps1` | 6 | 0 |
| `windows/scripts/setup-tailscale-ssh.ps1` | 122 (live code only — see §3 for the 4 here-string exceptions) | 0 |
| **Total** | **169 (164 live-code pairs + 5 helper-wrapper defs, counted separately)** | **0** |

Verification for the four small files (`bootstrap/install.ps1`, `install-pwsh-tools.ps1`,
`install-wezterm.ps1`, `lint.ps1`) and `scripts/install.ps1` was done by full manual line-by-line
comparison (all five are short enough to read in full). `setup-tailscale-ssh.ps1` (588 lines,
122 live conversions) was verified with a small Python script that regex-extracts
`(message, colour)` tuples from both the reconstructed original and the current file, in
document order, and asserts positional equality. Result: **0 mismatches, exact 1:1 order-preserving
match on message text and colour for every one of the 122 live-code conversions.**

No call site anywhere lost or gained an argument, and no message text or colour changed. **W1 and
W5 hold.**

## 2. Count reconciliation

Per-file original `Write-Host` inventory (from the reconstructed pre-conversion files, all call
sites including helper-definition wrappers):

| File | Orig. `Write-Host` count | Current `Write-Status` count (incl. wrapper defs) | Preserved `Write-Host` (here-string) | Reconciles? |
|---|---|---|---|---|
| `scripts/bootstrap/install.ps1` | 6 | 6 | 0 | ✅ 6 = 6 |
| `scripts/install.ps1` | 26 | 26 | 0 | ✅ 26 = 26 |
| `scripts/lint.ps1` | 7 | 7 | 0 | ✅ 7 = 7 |
| `windows/scripts/install-pwsh-tools.ps1` | 2 | 2 | 0 | ✅ 2 = 2 |
| `windows/scripts/install-wezterm.ps1` | 6 | 6 | 0 | ✅ 6 = 6 |
| `windows/scripts/setup-tailscale-ssh.ps1` | 126 | 122 | 4 | ✅ 122 + 4 = 126 |
| **Total** | **173** | **169** | **4** | ✅ **169 + 4 = 173** |

Arithmetic: `173 (all original Write-Host call sites across the 6 pre-existing files) − 4
(deliberately preserved inside the here-string) = 169 conversions.` This matches the commit
history precisely: commit `259068c`'s message states "Converted all 130 Write-Host calls in
the three existing windows/scripts files ... leaving the 4 inside setup-tailscale-ssh's
[here-string] untouched" (126 + 6 + 2 − 4 = 130 ✓), and commit `b7cec8d`'s message states
"scripts/install.ps1: 26 ... scripts/lint.ps1: 7 ... scripts/bootstrap/install.ps1: 6" (26 + 7 + 6
= 39). **130 + 39 = 169**, exactly matching the reconciliation above.

**Discrepancy with SPEC.md:** SPEC.md's Change 2 preamble states "163 `Write-Host` calls across
7 .ps1 files were mechanically converted." This is off from the true figure by 6 (169 actual vs.
163 stated), and the "7 files" framing is misleading — only 6 files were converted; the 7th
(`fix-stuck-driver-update.ps1`) is new code that uses `Write-Status` because it was written
that way from the start, not because anything in it was converted. This is a documentation
accuracy issue in the audit spec itself, not a code defect — flagging per the audit's own
instruction to report on invariants as stated, since a future reader could otherwise treat "163"
as a verified baseline.

## 3. Here-string preservation (W2)

`windows/scripts/setup-tailscale-ssh.ps1` contains three here-strings (`$infinityBlock`,
`$additions`, `$minimalConfig`, `$cleanupContent`ᐧ — four `@"..."@` blocks in total). Only
`$cleanupContent` (lines 547–571), which builds the generated `omc-cleanup.ps1` script written to
`$env:USERPROFILE\.local\bin\omc-cleanup.ps1`, contains `Write-Host` calls:

```
558:Write-Host "Cleaning OMC state on Infinity..." -ForegroundColor Cyan
562:    Write-Host "Cleanup complete." -ForegroundColor Green
564:    Write-Host "WARNING: Cleanup may have failed (exit `$LASTEXITCODE)" -ForegroundColor Yellow
568:    Write-Host "Connecting to Claude Code session..." -ForegroundColor Cyan
```

Checks:
- **(a) Exactly 4 remain** — `grep -c "Write-Host" windows/scripts/setup-tailscale-ssh.ps1` = 5,
  which is the 4 here-string calls + 1 explanatory comment ("`# Write-Host trips
  PSScriptAnalyzer's...`" at line 10). Confirmed exactly 4 call sites.
- **(b) Inside the here-string, not live code** — confirmed by direct inspection: all four sit
  between the `$cleanupContent = @"` opener (line 547) and the `"@` closer (line 571), i.e.
  inside the string literal that is later written to disk via `Write-UTF8`, not executed by the
  parent script.
- **(c) The generated script runs standalone** — the here-string defines its own
  `param([switch]`$Connect)`, its own `` `$InfinityHost `` variable, and calls `Write-Host`
  directly with no reference to the parent script's `Write-Status` function or any other symbol
  from the outer scope (all `$`-references inside are backtick-escaped so they resolve at
  *generated-script* runtime, not at *generator* runtime). It has no `Write-Status` helper
  defined in itself, and correctly doesn't need one — it never calls it. **Confirmed self-contained.**
- **Message/colour fidelity of the 4 preserved lines** — diffed against the pre-conversion
  original (`259068c~1`) line-for-line: identical text and colour in all 4 (`Cyan`, `Green`,
  `Yellow`, `Cyan`). Zero drift.
- **Other files' here-strings** — none of the other 5 converted files (`bootstrap/install.ps1`,
  `install.ps1`, `lint.ps1`, `install-pwsh-tools.ps1`, `install-wezterm.ps1`) contain any
  `@"`/`"@` here-string blocks at all (`grep -n '@"'` returns empty for all five), so there is no
  risk of a wrongly-converted here-string anywhere else in the repo.

**W2 holds in full.**

## 4. Runtime equivalence (W1, W3)

Extracted the current `Write-Status` helper verbatim and ran it under pwsh 7.6.5 (macOS arm64)
with: no colour; each of `Cyan`, `DarkGray`, `Green`, `Red`, `White`, `Yellow`, `Blue` (the 7
colours actually used anywhere in the repo — confirmed exhaustively, see below) plus `Gray` for
completeness; an empty string with and without a colour; a string with an already-expanded `` `$ ``
/backtick; and a 5,000-character string. All 12 cases were run twice: once as a normal `pwsh -File`
invocation and once with stdout fully redirected to a file.

**Result: zero exceptions in either mode**, for every colour and every edge case.

One caveat worth flagging plainly: in *both* the "normal" and "redirected" run in this sandboxed,
non-TTY shell, `$Host.UI.RawUI.ForegroundColor` reported `-1` — i.e. this environment could not
actually produce a genuine attached-console vs. redirected-console contrast; both runs exercised
the "no real console" code path. That path is precisely the one W3 is worried about, and it did
not throw, so the practical case in scope for this toolchain is covered — but this test does
**not** prove anything about a genuinely interactive Windows console session (untestable here;
see §5 for why that distinction turns out to matter more than expected).

**Colour validity check** — every colour string used anywhere in the repo
(`Blue`, `Cyan`, `DarkGray`, `Green`, `Red`, `White`, `Yellow` — enumerated via
`grep -rhoE "Write-Status\s+.*'[A-Za-z]+'\s*$"` across `scripts/` and `windows/scripts/`) was
validated against `[System.Enum]::GetNames([System.ConsoleColor])`. All 7 are valid members
(`Blue` and `Gray` included — full enum: `Black, DarkBlue, DarkGreen, DarkCyan, DarkRed,
DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White`). No
invalid colour string exists anywhere in the codebase, and a repo-wide grep for any leftover
`-ForegroundColor` confirms the only remaining usages are the 4 intentional here-string
`Write-Host` calls in §3 — no stray unconverted call sites.

## 5. PowerShell 5.1 compatibility (R4) — the significant finding

Windows PowerShell 5.1's console host implementation is closed-source, so nothing here could be
executed against a literal 5.1 binary (no Windows machine available, per SPEC's stated
constraints). The evidence below comes from PowerShell Core's public source
(`PowerShell/PowerShell` on GitHub), which shares the same class names, contracts, and
architecture as the Windows PowerShell 5.1 console host it descended from — this is the strongest
verification available without live Windows access, and is labeled ASSUMED where it extrapolates
to the literal 5.1 binary rather than VERIFIED.

**Q: Does `$Host.UI.WriteLine(string)` (the uncoloured branch) exist and work on 5.1?**
Yes — it's an `abstract` member of `PSHostUserInterface` present in every host implementation by
contract, back to PS v1. **VERIFIED / safe.**

**Q: Does `$Host.UI.RawUI.BackgroundColor`/`.ForegroundColor` (used by the coloured branch)
behave safely when there's no console — the exact scenario W3 is written to guard against?**

**This is where the SPEC's own stated premise doesn't hold on the platform that matters.** W3 says:

> `$Host.UI.RawUI.ForegroundColor` returns `-1` under redirection and `WriteLine` rejects `-1`
> as a *foreground* (tolerates it as background).

That `-1`-sentinel behaviour is real, but it is **specific to non-Windows pwsh** — confirmed via
`PowerShell/PowerShell#714` and `#14727`, both filed against macOS/Linux and closed "by design"
because those platforms don't expose a native console colour API the same way. It is also exactly
what this audit's own local tests reproduced (§4) — because the only toolchain available is pwsh
on macOS.

**On Windows** (the platform `scripts/install.ps1` and `scripts/bootstrap/install.ps1` actually
ship to, both under `#Requires -Version 5.1`), the underlying getter chain
(`ConsoleHostRawUserInterface.BackgroundColor` → `GetBufferInfo` → Win32
`GetConsoleScreenBufferInfo`) has **no `-1` fallback at all**. When there is no real console
screen buffer attached, it throws:

```csharp
// ConsoleControl.cs
bool result = NativeMethods.GetConsoleScreenBufferInfo(consoleHandle.DangerousGetHandle(), out bufferInfo);
if (!result)
{
    int err = Marshal.GetLastWin32Error();
    HostException e = CreateHostException(err, "GetConsoleScreenBufferInfo", ...);
    throw e;
}
```
(source: `src/Microsoft.PowerShell.ConsoleHost/host/msh/ConsoleControl.cs`), and nothing between
that throw site and a script's `$Host.UI.RawUI.BackgroundColor` read catches it
(`InternalHostRawUserInterface` just null-checks and passes the exception straight through).

**Corroborating this is not theoretical:** Microsoft's own `Write-Host` cmdlet reads this exact
same property (when `-BackgroundColor` isn't explicitly passed, `ConsoleColorCmdlet.BackgroundColor`'s
getter falls back to `this.Host.UI.RawUI.BackgroundColor` — verified directly from
`src/Microsoft.PowerShell.Commands.Utility/commands/utility/ConsoleColorCmdlet.cs`), and
**Microsoft wraps that exact read in a defensive try/catch specifically for this failure mode**,
in `WriteConsoleCmdlet.cs`:

```csharp
try
{
    informationMessage.ForegroundColor = ForegroundColor;
    informationMessage.BackgroundColor = BackgroundColor;
}
catch (System.Management.Automation.Host.HostException)
{
    // Expected if the host is not interactive, or doesn't have Foreground / Background colours.
}
```

**`Write-Status`'s coloured branch has no equivalent guard:**

```powershell
$Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
```

If `RawUI.BackgroundColor` throws `HostException` here, it propagates uncaught, and the script
terminates — whereas the original `Write-Host $Message -ForegroundColor $Color` this replaced
would have hit that exact same internal Microsoft try/catch and **silently continued** (the
colour info is simply dropped; the text still gets emitted via `WriteInformation`).

**Practically, when does this fire?** Not in the common case — an interactive PS 5.1 console
session run by double-clicking or typing the script at a prompt has a real console buffer, and
this never triggers. The risk is specific to non-interactive/no-buffer invocation contexts:
`-WindowStyle Hidden` (documented in `PowerShell/PSReadLine#310`, `#424`, `#1734`, all showing the
identical `GetConsoleScreenBufferInfo`/"handle is invalid" failure signature on Windows
PowerShell-era hosts, albeit via the BCL `Console` class rather than `PSHostRawUserInterface`
directly — same Win32 dependency, not a literal reproduction of this exact call path), being
launched with `CREATE_NO_WINDOW`/`DETACHED_PROCESS` by a parent process, some Scheduled Task
configurations, or being hosted inside a process that never allocates a console.

**Verdict: CONFIRMED via primary source that this is a real behavioural regression class — the
new code is *less* defensive than the code it replaced, for the specific fresh-machine/
unattended-bootstrap scenario these two scripts (`scripts/install.ps1`,
`scripts/bootstrap/install.ps1`) exist to serve.** Not reproduced against a literal Windows 5.1
binary (none available) — labeled ASSUMED at that layer, but the shared-architecture evidence is
about as strong as source-level analysis gets without one.

**Recommendation (not applied — read-only audit):** wrap the coloured branch:
```powershell
} else {
    try {
        $Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
    } catch [System.Management.Automation.Host.HostException] {
        $Host.UI.WriteLine($Message)
    }
}
```

## 6. Transcript capture (W4) — CONFIRMED FAILURE

Ran the actual current `Write-Status` helper under `Start-Transcript`/`Stop-Transcript` on pwsh
7.6.5, alongside a plain `Write-Host` and `Write-Output` call for comparison, in two independent
test forms (`pwsh -File` and `pwsh -Command`):

```
Write-Status 'status line 1'      # NOT in transcript
Write-Host   'host line 1'        # IS in transcript
Write-Output 'output line 1'      # IS in transcript
```

Transcript file contents (stripped of the standard header/footer) captured `host line 1` and
`output line 1`, but **not** `status line 1`, in both test runs. `$Host.UI.WriteLine()` bypasses
the transcription hook that `Write-Host`/`Write-Information` and the success-stream cmdlets go
through — `Start-Transcript` in PowerShell hooks the `Write-Host`/output-stream path, not raw
`PSHostUserInterface.WriteLine` calls.

**This directly contradicts W4** ("Output remains captured by `Start-Transcript`"). Every one of
the 169 converted call sites, across all 6 files, now silently vanishes from any transcript a user
or script starts around these scripts — a real, reproducible functional regression, not a
theoretical one. **Confirmed on the one toolchain available (pwsh 7.6.5); not independently tested
against Windows PowerShell 5.1's transcription implementation, but pwsh's transcription code path
descends from the same `System.Management.Automation.Internal.Host.InternalHost` /
`ConsoleHostUserInterface.WriteLine` transcription hook design, so there is no structural reason
to expect 5.1 to behave differently here — labeled CONFIRMED with high, but not Windows-verified,
confidence.**

---

## What this audit did NOT check

- Change 1 (`fix-stuck-driver-update.ps1`), Change 3 (function renames), Change 4 (lint.ps1
  defect repairs), and Change 5 (docs) are out of scope for this pass — see other audit files if
  present.
- Live behaviour on an actual Windows machine (Windows PowerShell 5.1, ISE, remoting hosts,
  Scheduled Task contexts) — none was available. §5 and §6's Windows-specific conclusions rest on
  PowerShell's public source and pwsh-on-macOS reproduction, not live Windows execution.
- Whether `Write-UTF8` (used to write the generated `omc-cleanup.ps1` to disk) is itself
  correctly implemented — out of scope for this conversion-focused audit.
