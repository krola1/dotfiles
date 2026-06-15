# Import Wayland/session variables into systemd --user.
# Needed so user services like swayidle/swaylock can see the compositor session.

if status is-interactive
    set -l systemd_user_vars \
        WAYLAND_DISPLAY \
        DISPLAY \
        XDG_CURRENT_DESKTOP \
        XDG_SESSION_TYPE \
        XDG_SESSION_DESKTOP \
        XDG_RUNTIME_DIR \
        DBUS_SESSION_BUS_ADDRESS \
        SWAYSOCK \
        NIRI_SOCKET

    systemctl --user import-environment $systemd_user_vars 2>/dev/null
end
