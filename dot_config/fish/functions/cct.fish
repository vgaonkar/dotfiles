function cct --description 'Launch Claude Code with the Telegram two-way channel (bridge session)'
    # One getUpdates reader per bot token: run ONE cct/bridge session at a time.
    # For always-on, launch inside tmux:  tmux new -s bridge cct
    claude --channels plugin:telegram@claude-plugins-official $argv
end
