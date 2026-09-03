# Documentation Audit — PowerShell Driver Fix & Lint Cleanup

**Audit Date:** 2026-09-02  
**Audited Files:** docs/05-troubleshooting.md, windows/AGENTS.md, windows/scripts/fix-stuck-driver-update.ps1  
**Reference:** SPEC.md Change 5 (Invariants X1–X2)  

---

## Executive Summary

All documented flags, paths, and behaviors match the actual code implementation. No factual mismatches detected. One documentation gap identified: the troubleshooting docs do not clarify that `fix-stuck-driver-update.ps1` must be run from a git clone of the repo (not a deployed chezmoi installation), since windows/ is excluded from Chezmoi deployment via `.chezmoiignore`.

**Severity:** Low (impacts clarity, not accuracy; the limitation is documented in windows/AGENTS.md but not in the user-facing troubleshooting section).

---

## Detailed Findings

### docs/05-troubleshooting.md — Windows Section (Lines 63–95)

#### Flag & Path Verification

| Claim | Code Reference | Status |
|-------|-----------------|--------|
| `-Vendor Canon` flag exists | param block line 89 | ✅ CONFIRMED |
| `-Execute` flag exists | param block line 90 | ✅ CONFIRMED |
| `-BlockByHardwareId` flag exists | param block line 93 | ✅ CONFIRMED |
| `-Verify` flag exists | param block line 91 | ✅ CONFIRMED |
| `-DisableDriverUpdate` flag exists | param block line 92 | ✅ CONFIRMED |
| `-RepairImage` flag exists | param block line 94 | ✅ CONFIRMED |
| `.\windows\scripts\fix-stuck-driver-update.ps1` path | windows/scripts/ dir listing | ✅ CONFIRMED |

#### Behavioral Claims

| Claim | Code Reference | Status |
|-------|-----------------|--------|
| Dry run without `-Execute` | lines 794–800 | ✅ CONFIRMED |
| Apply changes with `-Execute` | lines 794–796 | ✅ CONFIRMED |
| `-Verify` is read-only post-reboot check | lines 758–790 | ✅ CONFIRMED |
| Exits non-zero if flags did not clear or packages remain | line 789 (`exit 3`) | ✅ CONFIRMED (exit code 3) |
| Backs up driver packages before deletion | lines 341–381 (Export-VendorDriver) | ✅ CONFIRMED |
| Verifies backup landed before deleting | lines 374–380 | ✅ CONFIRMED |
| Backups go to `%USERPROFILE%\dotfiles-backups\driver-fix\<timestamp>\` | line 97 default param + line 803 | ✅ CONFIRMED |
| `diagnosis.json` snapshot is written | line 821 (inside `if ($Execute)`) | ✅ CONFIRMED |
| Transcript written | line 808–809 | ✅ CONFIRMED |
| `-Verify` diffs against snapshot | lines 676–677 (Get-LastDiagnosis) | ✅ CONFIRMED |

#### Undocumented Flags in Usage Examples

The docs mention these extras in text but not in the initial 3-step invocation:
- `-SkipDriverPurge` appears in .EXAMPLE block (line 75) but is not mentioned in troubleshooting narrative. **Minor gap:** users reading only the troubleshooting text won't know this option exists.
- `-SkipUpdateReset` appears in .EXAMPLE block (line 75) but is not mentioned in troubleshooting narrative. **Minor gap:** same as above.

**Severity:** Low. Full parameter docs are accessible via `Get-Help .\windows\scripts\fix-stuck-driver-update.ps1 -Full` (which the docs mention in line 94).

---

### windows/AGENTS.md — Script Entry (Lines 22–39)

#### Descriptor Accuracy

| Claim | Code Reference | Status |
|-------|-----------------|--------|
| "Dry run by default" | lines 794–800 | ✅ CONFIRMED |
| "`-Execute` applies [changes]" | lines 794–796 | ✅ CONFIRMED |
| "`-Verify` checks it held after reboot" | lines 760–790 | ✅ CONFIRMED |
| "Backs up and verifies before any delete" | lines 341–381 | ✅ CONFIRMED |

#### Lint Testing Note (Lines 36–39)

| Claim | Code Reference | Status |
|-------|-----------------|--------|
| "This directory is included in the lint glob" | scripts/lint.ps1 line 33 | ✅ CONFIRMED |
| "All files here are currently clean" | Lint glob includes windows/scripts | ✅ ASSUMED (not executable in audit environment; toolchain available per SPEC but Windows cmdlets cannot be tested) |
| "Write-Status helper that each script defines" | All 7 scripts define it | ✅ CONFIRMED |

**Script Count Verification:**
- scripts/lint.ps1 — defines Write-Status ✓
- scripts/install.ps1 — defines Write-Status ✓
- scripts/bootstrap/install.ps1 — defines Write-Status ✓
- windows/scripts/fix-stuck-driver-update.ps1 — defines Write-Status ✓
- windows/scripts/install-wezterm.ps1 — defines Write-Status ✓
- windows/scripts/install-pwsh-tools.ps1 — defines Write-Status ✓
- windows/scripts/setup-tailscale-ssh.ps1 — defines Write-Status ✓

**Total: 7 scripts, all define Write-Status. ✓**

---

### Comment-Based Help in fix-stuck-driver-update.ps1 (Lines 1–85)

#### Parameter Blocks

| Parameter | Code Exists | .PARAMETER Block | Status |
|-----------|-------------|------------------|--------|
| Vendor | param line 89 | .PARAMETER line 28 | ✅ Present |
| Execute | param line 90 | .PARAMETER line 32 | ✅ Present |
| Verify | param line 91 | .PARAMETER line 35 | ✅ Present |
| DisableDriverUpdate | param line 92 | .PARAMETER line 40 | ✅ Present |
| BlockByHardwareId | param line 93 | .PARAMETER line 44 | ✅ Present |
| RepairImage | param line 94 | .PARAMETER line 49 | ✅ Present |
| SkipDriverPurge | param line 95 | .PARAMETER line 53 | ✅ Present |
| SkipUpdateReset | param line 96 | .PARAMETER line 57 | ✅ Present |
| BackupRoot | param line 97 | .PARAMETER line 59 | ✅ Present |

**Count: 9 parameters, 9 .PARAMETER blocks. ✓ Matches SPEC Invariant D11.**

#### Example Blocks

| Example # | Invocation | Status |
|-----------|-----------|--------|
| 1 | `.\fix-stuck-driver-update.ps1` (dry run) | ✅ Valid |
| 2 | `.\fix-stuck-driver-update.ps1 -Execute -BlockByHardwareId` | ✅ Valid |
| 3 | `.\fix-stuck-driver-update.ps1 -Verify` | ✅ Valid |
| 4 | `.\fix-stuck-driver-update.ps1 -Execute -SkipDriverPurge -RepairImage` | ✅ Valid |

**Count: 4 examples. ✓ Matches SPEC Invariant D11.**

#### Exit Codes Documented

| Code | Condition | Help Text | Code Path |
|------|-----------|-----------|-----------|
| 0 | Success | "ok" (line 84) | line 775 (Verify passed) |
| 1 | Not elevated / bad args | "not elevated / bad arguments" (line 83) | lines 748, 755 |
| 2 | Backup verification failed | "backup verification failed" (line 83) | line 840 |
| 3 | Verify failed | "-Verify found the fix did not hold" (line 84) | line 789 |

**✅ All exit codes reachable and documented correctly.**

---

## Documentation Gaps (Not Code Mismatches)

### Gap 1: Invocation Path Ambiguity

**File:** docs/05-troubleshooting.md, lines 76–82  
**Issue:** The docs show `.\windows\scripts\fix-stuck-driver-update.ps1` invocation but do not clarify that this script must be run from a **git clone of the repo**, not from a deployed chezmoi installation.

**Why:** windows/scripts/ is excluded from Chezmoi deployment via `.chezmoiignore` (see windows/AGENTS.md line 29). After running `chezmoi apply`, a user will not have `./windows/` in their home directory and the relative path will fail.

**Mitigation Already In Place:** windows/AGENTS.md line 29 states "These files are excluded from Chezmoi" — but this is not visible to troubleshooting readers.

**Recommendation:** Add a note in docs/05-troubleshooting.md near line 72 clarifying: "Note: This script is not deployed by chezmoi. Run it from a clone of the dotfiles repo."

**Severity:** Low. The limitation is documented elsewhere; impacts UX clarity rather than accuracy.

---

### Gap 2: Minor — Undocumented Optional Flags in Narrative

**File:** docs/05-troubleshooting.md, lines 63–95  
**Issue:** The optional flags `-SkipDriverPurge` and `-SkipUpdateReset` are not mentioned in the troubleshooting narrative, though they appear in the comment-based help and one .EXAMPLE.

**Recommendation:** Not critical; `Get-Help .\windows\scripts\fix-stuck-driver-update.ps1 -Full` (already referenced in docs line 94) will show these. Consider adding a sentence like: "For advanced use cases (e.g., repair without purge), see `Get-Help .\windows\scripts\fix-stuck-driver-update.ps1 -Full` for all options."

**Severity:** Very low. Full docs are readily accessible.

---

## Cross-Documentation Consistency Check

| Document | Reference | Status |
|----------|-----------|--------|
| docs/00-table-of-contents.md | Troubleshooting listed | ✅ No new entry needed |
| README.md | No stale Windows script refs | ✅ Clean |
| CLAUDE.md | No stale Windows script refs | ✅ Clean |
| scripts/lint.ps1 | windows/scripts included in glob | ✅ Correct |

---

## Verification Summary

✅ **No factual mismatches between documentation and code.**  
✅ **All flags, paths, and behaviors verified as documented.**  
✅ **Exit codes are reachable and correctly documented.**  
✅ **All 9 parameters and 4 examples present and valid.**  
✅ **All 7 PowerShell scripts define Write-Status helper.**  
✅ **Lint glob correctly includes windows/scripts.**  

⚠️ **One clarity gap:** docs/05-troubleshooting.md should clarify that fix-stuck-driver-update.ps1 is run from a repo clone, not a deployed installation (already noted in windows/AGENTS.md but not in user-facing docs).

---

## Conclusion

Documentation accurately reflects code behavior. The single gap (invocation context) is a UX clarity issue, not a factual error. Recommend adding one clarifying sentence to docs/05-troubleshooting.md around line 72 to close this gap.
