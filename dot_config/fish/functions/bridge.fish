function bridge --description 'Open or re-attach THE single Telegram two-way bridge (tmux session: tg-bridge)'
    # One getUpdates reader per token -> there is exactly ONE bridge, always named tg-bridge.
    # `bridge`        -> attach if it exists, else create it running cct.
    # `tmux ls`       -> shows whether tg-bridge is alive.
    # `tmux kill-session -t tg-bridge` -> stop the bridge.
    if tmux has-session -t tg-bridge 2>/dev/null
        tmux attach -t tg-bridge
    else
        tmux new -s tg-bridge "claude --channels plugin:telegram@claude-plugins-official"
    end
end
