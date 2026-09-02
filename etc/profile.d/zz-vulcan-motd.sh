# zz-vulcan-motd.sh — Vulcan login MOTD hook.
# Runs as the user from /etc/profile.d. The guards below are load-bearing:
# printing anything in a non-interactive session corrupts scp/sftp/rsync.
# Do not remove them.

case $- in
    *i*) ;;                      # interactive shells only
    *) return 0 2>/dev/null || exit 0 ;;
esac
[ -t 1 ] || return 0 2>/dev/null || exit 0        # stdout must be a tty
case "${TERM:-dumb}" in
    ''|dumb) return 0 2>/dev/null || exit 0 ;;
esac
# Suppress for root shells: sudo -i, sudo -s, su -, direct root login. Root
# sees no jobs/fairshare anyway and shouldn't pay the render tax. Sits after
# the interactive/tty checks so it never weakens scp/sftp/rsync safety.
[ "$(id -u)" -eq 0 ] && { return 0 2>/dev/null || exit 0; }
[ -n "${VULCAN_MOTD_OFF:-}" ] && { return 0 2>/dev/null || exit 0; }
[ -e "$HOME/.hushlogin" ] && { return 0 2>/dev/null || exit 0; }

# /etc/profile.d is sourced twice at login on Ubuntu (/etc/bash.bashrc and
# /etc/profile both loop over it) — render only once per session.
[ -n "${VULCAN_MOTD_SHOWN:-}" ] && { return 0 2>/dev/null || exit 0; }
VULCAN_MOTD_SHOWN=1; export VULCAN_MOTD_SHOWN

command -v vulcan-status >/dev/null 2>&1 && timeout 6 vulcan-status
true
