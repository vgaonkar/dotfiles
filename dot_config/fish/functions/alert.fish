function alert
    set -l last_status $status
    set -l icon (test $last_status -eq 0; and echo terminal; or echo error)
    set -l cmd (history --max 1 | string replace -r '^\s*\d+\s*' '' | string replace -r '[;&|]\s*alert$' '')
    if type -q notify-send
        notify-send --urgency=low -i $icon "Command: $cmd" "Finished with status: $last_status"
    else if type -q osascript
        osascript -e "display notification \"Finished with status: $last_status\" with title \"Command: $cmd\""
    end
end
