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

OMC_BASE="/home/dev/.claude/plugins"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

TMPFILE_DEEP="" TMPFILE_FLAT="" TMPFILE_BUNDLE=""
trap 'rm -f "$TMPFILE_DEEP" "$TMPFILE_FLAT" "$TMPFILE_BUNDLE"' EXIT

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

# --- Build insertion blocks ---
TMPFILE_DEEP=$(mktemp)
TMPFILE_FLAT=$(mktemp)

# For TS files (indented with comment header, anchor: "note: 'none',")
{
    echo ""
    echo "  // === Custom skills (instruction-loaders, no protection needed) ==="
    for skill in "${CUSTOM_SKILLS[@]}"; do
        echo "  '${skill}': 'none',"
    done
} > "$TMPFILE_DEEP"

# For MJS/JS/CJS files (flat entries, anchor: "deepinit: 'heavy',")
{
    for skill in "${CUSTOM_SKILLS[@]}"; do
        echo "  '${skill}': 'none',"
    done
} > "$TMPFILE_FLAT"

# For bundled cli.cjs files (double quotes, no trailing comma, anchor: 'deepinit: "heavy"')
TMPFILE_BUNDLE=$(mktemp)
{
    for skill in "${CUSTOM_SKILLS[@]}"; do
        echo "      \"${skill}\": \"none\","
    done
} > "$TMPFILE_BUNDLE"

# --- Find and patch ALL files containing SKILL_PROTECTION ---
ALL_FILES=$(grep -rl "SKILL_PROTECTION" "$OMC_BASE" 2>/dev/null | grep -v node_modules | grep -v '__tests__' | grep -v '.test.' | grep -v '.jsonl')

PATCHED=0
SKIPPED=0

for file in $ALL_FILES; do
    if grep -q 'phase-resume' "$file"; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Determine which anchor and insertion block to use
    if grep -q "note: 'none'," "$file"; then
        # TS-style file with note: 'none' anchor
        sed -i "/note: 'none',/r $TMPFILE_DEEP" "$file"
    elif grep -q "deepinit: 'heavy'," "$file"; then
        # MJS/JS/CJS-style file with deepinit anchor (single quotes)
        sed -i "/deepinit: 'heavy',/r $TMPFILE_FLAT" "$file"
    elif grep -q 'deepinit: "heavy"' "$file"; then
        # Bundled cli.cjs file (double quotes, no trailing comma)
        sed -i '/deepinit: "heavy"/r '"$TMPFILE_BUNDLE" "$file"
    else
        warn "No known anchor in $file, skipping"
        continue
    fi

    if grep -q 'phase-resume' "$file"; then
        info "Patched: $file"
        PATCHED=$((PATCHED + 1))
    else
        warn "Patch may have failed: $file"
    fi
done

if [[ $PATCHED -eq 0 && $SKIPPED -gt 0 ]]; then
    info "All $SKIPPED files already patched (or upstream fix landed)"
elif [[ $PATCHED -gt 0 ]]; then
    info "Patched $PATCHED file(s), $SKIPPED already done"
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
