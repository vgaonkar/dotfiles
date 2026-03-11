#!/usr/bin/env bash
# ==============================================================================
# patch-omc-skill-protection.sh
#
# Patches oh-my-claudecode's skill protection maps to register custom skills
# with 'none' protection level, so they don't trigger reinforcement prompts.
#
# This is a workaround for OMC not supporting custom skill protection levels.
# Custom skills are instruction-loaders that pose no risk and need no protection.
#
# See: https://github.com/Yeachan-Heo/oh-my-claudecode/issues/1581
#
# Run this after every `omc update` to re-apply the patch.
# ==============================================================================
set -eo pipefail

TS_FILE="/home/dev/.claude/plugins/marketplaces/omc/src/hooks/skill-state/index.ts"
MJS_FILE="/home/dev/.claude/plugins/marketplaces/omc/scripts/pre-tool-enforcer.mjs"
TEMPLATE_FILE="/home/dev/.claude/plugins/marketplaces/omc/templates/hooks/pre-tool-use.mjs"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

TMPFILE="" TMPFILE2="" TMPFILE3=""
trap 'rm -f "$TMPFILE" "$TMPFILE2" "$TMPFILE3"' EXIT

# --- Pre-flight checks ---
[[ -f "$TS_FILE" ]]       || error "TypeScript source not found: $TS_FILE"
[[ -f "$MJS_FILE" ]]      || error "Deployed script not found: $MJS_FILE"
[[ -f "$TEMPLATE_FILE" ]] || error "Template hook not found: $TEMPLATE_FILE"

# --- Check if upstream fix has landed (all 3 files must have it) ---
if grep -q 'phase-resume' "$TS_FILE" && grep -q 'phase-resume' "$MJS_FILE" && grep -q 'phase-resume' "$TEMPLATE_FILE"; then
    info "Upstream fix detected in all 3 files, no patch needed"
    exit 0
fi

# --- Custom skills to add (instruction-loaders, no protection needed) ---
CUSTOM_SKILLS=(
    phase-resume
    phase-complete
    phase-runner
    phase-plan
    skill-sync
    research
    deploy
    deep-verify
    config-backup
    diff-audit
    dockerize
    fullstack-launch
    fullstack-upgrade
    maintenance-schedule
    monitor-setup
    post-mortem
    project-health
    project-tidy
    resume-update
    riceco-kickoff
    skill-create
    linkedin-sync
    omc-coach
)

# ==============================================================================
# Patch 1: TypeScript source (src/hooks/skill-state/index.ts)
# ==============================================================================
if grep -q 'Custom skills (instruction-loaders' "$TS_FILE"; then
    info "TypeScript source already patched, skipping"
else
    info "Patching TypeScript source: $TS_FILE"

    # Build insertion block in a temp file
    TMPFILE=$(mktemp)

    {
        echo ""
        echo "  // === Custom skills (instruction-loaders, no protection needed) ==="
        for skill in "${CUSTOM_SKILLS[@]}"; do
            echo "  '${skill}': 'none',"
        done
    } > "$TMPFILE"

    # Anchor: insert after "note: 'none'," in the instant/read-only block
    sed -i "/^  note: 'none',$/r $TMPFILE" "$TS_FILE"

    if grep -q 'phase-resume' "$TS_FILE"; then
        info "TypeScript source patched successfully"
    else
        error "TypeScript source patch failed"
    fi
fi

# ==============================================================================
# Patch 2: Deployed script (scripts/pre-tool-enforcer.mjs)
# ==============================================================================
if grep -q 'phase-resume' "$MJS_FILE"; then
    info "Deployed script already patched, skipping"
else
    info "Patching deployed script: $MJS_FILE"

    # Build insertion block in a temp file
    TMPFILE2=$(mktemp)

    {
        for skill in "${CUSTOM_SKILLS[@]}"; do
            echo "  '${skill}': 'none',"
        done
    } > "$TMPFILE2"

    # Anchor: insert after "deepinit: 'heavy'," line
    sed -i "/^  deepinit: 'heavy',$/r $TMPFILE2" "$MJS_FILE"

    if grep -q 'phase-resume' "$MJS_FILE"; then
        info "Deployed script patched successfully"
    else
        error "Deployed script patch failed"
    fi
fi

# ==============================================================================
# Patch 3: Template hook (templates/hooks/pre-tool-use.mjs)
# This is the file that ACTUALLY RUNS as the pre-tool-use hook.
# ==============================================================================
if grep -q 'phase-resume' "$TEMPLATE_FILE"; then
    info "Template hook already patched, skipping"
else
    info "Patching template hook: $TEMPLATE_FILE"

    # Build insertion block in a temp file
    TMPFILE3=$(mktemp)

    {
        for skill in "${CUSTOM_SKILLS[@]}"; do
            echo "  '${skill}': 'none',"
        done
    } > "$TMPFILE3"

    # Anchor: insert after "deepinit: 'heavy'," line
    sed -i "/^  deepinit: 'heavy',$/r $TMPFILE3" "$TEMPLATE_FILE"

    if grep -q 'phase-resume' "$TEMPLATE_FILE"; then
        info "Template hook patched successfully"
    else
        error "Template hook patch failed"
    fi
fi

# ==============================================================================
# Clean up stale skill-active-state.json files
# ==============================================================================
info "Cleaning up stale skill state files..."
STALE_COUNT=$(find /home/dev/Projects -name "skill-active-state.json" -print -delete 2>/dev/null | wc -l)
info "Deleted $STALE_COUNT stale skill-active-state.json file(s)"

# ==============================================================================
# Summary
# ==============================================================================
echo ""
info "Patch complete! ${#CUSTOM_SKILLS[@]} custom skills registered with 'none' protection."
info "Re-run this script after every 'omc update'."
