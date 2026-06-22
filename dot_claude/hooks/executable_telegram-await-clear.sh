#!/usr/bin/env bash
# UserPromptSubmit hook — you just engaged, so cancel any pending idle ping
# for this session by invalidating its nonce marker.
set -euo pipefail
INPUT="$(cat)"
SID="$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo unknown)"
rm -f "$HOME/.claude/.await/$SID" 2>/dev/null || true
exit 0
