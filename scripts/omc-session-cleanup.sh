#!/usr/bin/env bash
# omc-session-cleanup.sh — Clean stale OMC state after SSH disconnect
#
# Triggered by:
#   1. tmux client-detached hook (automatic on disconnect)
#   2. Manual run: ~/.local/bin/omc-session-cleanup.sh
#
# Safe to run multiple times — only removes ephemeral state files.

set -euo pipefail

DEVELOPMENT_DIR="$HOME/Development"
OMC_ROOT="$HOME/.omc/state"
CLAUDE_TEAMS="$HOME/.claude/teams"
CLAUDE_TASKS="$HOME/.claude/tasks"

cleaned=0

# 1. Clean stale OMC state files (ephemeral per-session)
for state_dir in "$OMC_ROOT" "$DEVELOPMENT_DIR/.omc/state"; do
  if [ -d "$state_dir" ]; then
    for f in mission-state.json subagent-tracking.json last-tool-error.json \
             idle-notif-cooldown.json hud-state.json hud-stdin-cache.json; do
      if [ -f "$state_dir/$f" ]; then
        rm -f "$state_dir/$f"
        cleaned=$((cleaned + 1))
      fi
    done
    # Clean agent replay logs
    for f in "$state_dir"/agent-replay-*.jsonl; do
      [ -f "$f" ] && rm -f "$f" && cleaned=$((cleaned + 1))
    done
  fi
done

# 2. Clean per-project .omc state (scan top-level repos)
for repo_omc in "$DEVELOPMENT_DIR"/*/.omc/state; do
  if [ -d "$repo_omc" ]; then
    for f in mission-state.json subagent-tracking.json last-tool-error.json \
             idle-notif-cooldown.json hud-state.json hud-stdin-cache.json; do
      if [ -f "$repo_omc/$f" ]; then
        rm -f "$repo_omc/$f"
        cleaned=$((cleaned + 1))
      fi
    done
  fi
done

# 3. Clean stale team files (teams are ephemeral per-session)
if [ -d "$CLAUDE_TEAMS" ]; then
  team_count=$(find "$CLAUDE_TEAMS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [ "$team_count" -gt 0 ]; then
    rm -rf "${CLAUDE_TEAMS:?}"/*
    cleaned=$((cleaned + team_count))
  fi
fi

# 4. Clean stale task lists (tied to teams)
if [ -d "$CLAUDE_TASKS" ]; then
  task_count=$(find "$CLAUDE_TASKS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [ "$task_count" -gt 0 ]; then
    rm -rf "${CLAUDE_TASKS:?}"/*
    cleaned=$((cleaned + task_count))
  fi
fi

if [ "$cleaned" -gt 0 ]; then
  echo "[omc-cleanup] Cleaned $cleaned stale state files ($(date '+%H:%M:%S'))"
else
  echo "[omc-cleanup] Nothing to clean ($(date '+%H:%M:%S'))"
fi
