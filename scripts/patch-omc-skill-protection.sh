#!/usr/bin/env bash
# ==============================================================================
# patch-omc-skill-protection.sh
#
# Patches oh-my-claudecode's skill protection default from 'light' to 'none'
# for unknown skills. Without this patch, ANY skill not in OMC's built-in
# SKILL_PROTECTION map defaults to 'light', which writes skill-active-state.json
# and blocks the Stop hook for up to 3 reinforcements / 5 minutes.
#
# Custom skills are instruction-loaders that pose no risk and need no protection.
# Built-in skills that need protection are already explicitly listed in the map.
#
# See: https://github.com/Yeachan-Heo/oh-my-claudecode/issues/1581
#
# Run this after every `omc update` to re-apply the patch.
# ==============================================================================
set -eo pipefail

OMC_BASE="/home/dev/.claude/plugins"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ==============================================================================
# Phase 1: Change default fallback from 'light' to 'none'
#
# This is the core fix. Instead of maintaining an ever-growing list of custom
# skills, we change the default so unknown skills get 'none' protection.
# All OMC built-in skills that need protection are already explicitly listed.
#
# Target patterns (all variants across TS, MJS, JS, CJS files):
#   return SKILL_PROTECTION[normalized] ?? 'light';
#   return SKILL_PROTECTION_MAP[normalized] || 'light';
#   return SKILL_PROTECTION[normalized] || 'light';
#   (bundled) ... || "light"
# ==============================================================================

ALL_FILES=$(grep -rl "SKILL_PROTECTION" "$OMC_BASE" 2>/dev/null \
    | grep -v node_modules | grep -v '__tests__' | grep -v '.test.' | grep -v '.jsonl') || true

if [[ -z "$ALL_FILES" ]]; then
    error "No SKILL_PROTECTION files found in $OMC_BASE — is OMC installed?"
fi

DEFAULT_PATCHED=0
DEFAULT_ALREADY=0

for file in $ALL_FILES; do
    # Check if already patched (default is already 'none')
    if grep -qE "(SKILL_PROTECTION\w*\[normalized\].*\?\?|\|\|)\s*['\"]none['\"]" "$file" 2>/dev/null; then
        DEFAULT_ALREADY=$((DEFAULT_ALREADY + 1))
        continue
    fi

    # Patch: replace 'light' default with 'none' in getSkillProtection functions
    # Pattern 1: ?? 'light' (TS nullish coalescing)
    if grep -q "?? 'light'" "$file"; then
        sed -i "s/?? 'light'/?? 'none'/g" "$file"
    fi
    # Pattern 2: || 'light' (JS/MJS logical OR, single quotes)
    if grep -q "|| 'light'" "$file"; then
        sed -i "s/|| 'light'/|| 'none'/g" "$file"
    fi
    # Pattern 3: || "light" (bundled CJS, double quotes)
    if grep -q '|| "light"' "$file"; then
        sed -i 's/|| "light"/|| "none"/g' "$file"
    fi
    # Pattern 4: ?? "light" (bundled CJS nullish coalescing)
    if grep -q '?? "light"' "$file"; then
        sed -i 's/?? "light"/?? "none"/g' "$file"
    fi

    # Verify the patch took effect
    if grep -qE "(SKILL_PROTECTION\w*\[normalized\].*\?\?|\|\|)\s*['\"]none['\"]" "$file" 2>/dev/null; then
        info "Patched default: $file"
        DEFAULT_PATCHED=$((DEFAULT_PATCHED + 1))
    else
        # Check if the file even has a getSkillProtection function
        if grep -q "getSkillProtection" "$file"; then
            warn "Could not verify patch in: $file"
        fi
    fi
done

if [[ $DEFAULT_PATCHED -eq 0 && $DEFAULT_ALREADY -gt 0 ]]; then
    info "All $DEFAULT_ALREADY files already have 'none' default (patch applied or upstream fix landed)"
elif [[ $DEFAULT_PATCHED -gt 0 ]]; then
    info "Patched default in $DEFAULT_PATCHED file(s), $DEFAULT_ALREADY already done"
else
    warn "No files needed default patching — check if OMC structure changed"
fi

# ==============================================================================
# Phase 2: Clean up stale skill-active-state.json files
# ==============================================================================
info "Cleaning up stale skill state files..."
STALE_COUNT=$(find /home/dev/Projects -name "skill-active-state.json" -print -delete 2>/dev/null | wc -l)
if [[ $STALE_COUNT -gt 0 ]]; then
    info "Deleted $STALE_COUNT stale skill-active-state.json file(s)"
else
    info "No stale skill state files found"
fi

# Also clean from home .claude directory (session-scoped state)
STALE_HOME=$(find /home/dev/.claude -name "skill-active-state.json" -print -delete 2>/dev/null | wc -l)
if [[ $STALE_HOME -gt 0 ]]; then
    info "Deleted $STALE_HOME stale skill state file(s) from ~/.claude"
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
info "Patch complete! Default protection for unknown skills changed from 'light' to 'none'."
info "Built-in skills with explicit protection levels are unaffected."
info "Re-run this script after every 'omc update'."
