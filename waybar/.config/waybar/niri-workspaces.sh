#!/usr/bin/env bash
# Egendefinert workspace-modul: viser "1 2 3 4" som niri/workspaces,
# men når fokusert workspace er den skjulte "stash"-scratchpaden,
# dekker den hele modulen med et overlay-merke i stedet for å skvise
# seg inn i tallrekken.
set -Eeuo pipefail

render() {
    local ws_json
    ws_json="$(niri msg -j workspaces)"

    local focused_name
    focused_name="$(jq -r '.[] | select(.is_focused) | .name // empty' <<<"$ws_json")"

    if [[ "$focused_name" == "stash" ]]; then
        printf '%s\n' '<span font_weight="bold" foreground="#ffeacc"> STASH</span>'
        return
    fi

    jq -r '
        [.[] | select(.is_hidden | not)] | sort_by(.idx) |
        map(
            if .is_focused then
                "<span font_weight=\"bold\" foreground=\"#ffeacc\">\(.idx)</span>"
            else
                "\(.idx)"
            end
        ) | join("  ")
    ' <<<"$ws_json"
}

render

niri msg -j event-stream | while read -r line; do
    case "$line" in
        *WorkspacesChanged*|*WorkspaceActivated*)
            render
            ;;
    esac
done
