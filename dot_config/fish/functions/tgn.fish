function tgn --description 'Send a Telegram notification to your phone via the tg-notify helper'
    # Outbound only (no polling) -> safe from any/all sessions, unlimited concurrency.
    # Usage: tgn "deal-radar: waiting on your input about the schema"
    ~/.claude/channels/telegram/notify.sh $argv
end
