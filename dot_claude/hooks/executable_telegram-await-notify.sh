#!/usr/bin/env bash
# Stop hook — "away-only" Telegram notifier.
# Fires when a session finishes a turn. Records a per-session nonce, then waits
# AWAIT_SECS in the background; if no new prompt/turn superseded it (i.e. you
# walked away), sends ONE labeled Telegram ping. Active chatting -> no pings.
set -euo pipefail
AWAIT_SECS="${TG_AWAIT_SECS:-120}"
INPUT="$(cat)"
SID="$(printf '%s' "$INPUT"  | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
CWD="$(printf '%s' "$INPUT"  | jq -r '.cwd // ""'              2>/dev/null || echo '')"
PROJ="$(basename "${CWD:-$PWD}")"
DIR="$HOME/.claude/.await"; mkdir -p "$DIR"
FILE="$DIR/$SID"
NONCE="$(date +%s)-$$-${RANDOM}"
printf '%s\n' "$NONCE" > "$FILE"
# Detached delayed check; foreground returns immediately so the hook doesn't block.
( sleep "$AWAIT_SECS"
  cur="$(cat "$FILE" 2>/dev/null || echo '')"
  if [ "$cur" = "$NONCE" ]; then
    "$HOME/.claude/channels/telegram/notify.sh" "⏳ ${PROJ}: session idle ${AWAIT_SECS}s — waiting on your input." >/dev/null 2>&1 || true
    rm -f "$FILE" 2>/dev/null || true
  fi
) >/dev/null 2>&1 &
exit 0
