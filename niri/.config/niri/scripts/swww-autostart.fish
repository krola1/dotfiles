#!/usr/bin/env fish

niri msg event-stream | while read -l line
    if string match -qi "*output:*" -- $line
        echo (date) "Skjermendring oppdaget – restarter swww-daemon"
        pkill -HUP swww-daemon
        swww-daemon
    end
end
