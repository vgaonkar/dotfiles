function alert
    set -l last_status $status
    set -l icon (test $last_status -eq 0; and echo terminal; or echo error)
    set -l cmd (history --max 1 | string replace -r '^\s*\d+\s*' '' | string replace -r '[;&|]\s*alert$' '')
    notify-send --urgency=low -i $icon "Command: $cmd" "Finished with status: $last_status"
end
