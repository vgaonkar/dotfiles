#!/usr/bin/env bash
# tg-notify: send a Telegram message from ANY Claude session (outbound only,
# no polling -> safe to run from unlimited concurrent sessions on one token).
# Usage: notify.sh "message text"
set -euo pipefail
DIR="$HOME/.claude/channels/telegram"
TOKEN="$(sed -n 's/^TELEGRAM_BOT_TOKEN=//p' "$DIR/.env" 2>/dev/null || true)"
CHAT="$(sed -n 's/^TELEGRAM_CHAT_ID=//p' "$DIR/notify.conf" 2>/dev/null || true)"
MSG="${1:-(no message)}"
if [ -z "$TOKEN" ] || [ -z "$CHAT" ]; then
  echo "tg-notify: missing token or chat_id" >&2; exit 1
fi
curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT}" \
  --data-urlencode "text=${MSG}" \
  -o /dev/null -w '%{http_code}\n'
