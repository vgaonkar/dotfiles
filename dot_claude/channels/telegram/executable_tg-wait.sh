#!/usr/bin/env bash
# tg-wait: block until you send the bot a NEW message, then print that text.
# Long-polls getUpdates. ONE poller per token -> do NOT run while a `cct` bridge
# (or another tg-wait) is active on this token. Send (notify.sh) is unaffected.
# Env: TG_WAIT_TIMEOUT overall give-up seconds (default 540).
set -uo pipefail
DIR="$HOME/.claude/channels/telegram"
TOKEN="$(sed -n 's/^TELEGRAM_BOT_TOKEN=//p' "$DIR/.env" 2>/dev/null)"
CHAT="$(sed -n 's/^TELEGRAM_CHAT_ID=//p' "$DIR/notify.conf" 2>/dev/null)"
[ -n "$TOKEN" ] && [ -n "$CHAT" ] || { echo "tg-wait: token/chat missing" >&2; exit 1; }
api="https://api.telegram.org/bot${TOKEN}"
ok(){ printf '%s' "$1" | jq -e '.ok==true' >/dev/null 2>&1; }
# Prime: skip any backlog so we only wait for a FRESH reply.
prime="$(curl -s "${api}/getUpdates?offset=-1")"
if ! ok "$prime"; then echo "tg-wait: $(printf '%s' "$prime" | jq -r '.description // "telegram error"')" >&2; exit 3; fi
offset="$(printf '%s' "$prime" | jq -r '((.result // [])[-1].update_id // -1) + 1')"
deadline=$(( $(date +%s) + ${TG_WAIT_TIMEOUT:-540} ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  resp="$(curl -s "${api}/getUpdates?timeout=30&offset=${offset}")"
  [ -z "$resp" ] && continue
  if ! ok "$resp"; then echo "tg-wait: $(printf '%s' "$resp" | jq -r '.description // "telegram error"')" >&2; exit 3; fi
  newlast="$(printf '%s' "$resp" | jq -r '(.result // [])[-1].update_id // empty')"
  [ -n "$newlast" ] && offset=$((newlast+1))
  msg="$(printf '%s' "$resp" | jq -r --arg c "$CHAT" '(.result // [])[]|select((.message.chat.id|tostring)==$c)|.message.text // empty' | tail -1)"
  [ -n "$msg" ] && { printf '%s\n' "$msg"; exit 0; }
done
echo "tg-wait: no reply within timeout" >&2; exit 2
