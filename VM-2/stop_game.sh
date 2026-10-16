
#!/usr/bin/env bash
#
# stop_game.sh - stop the demo server and return the VM to a clean, secure state.
#
#   sudo ./stop_game.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=80

[[ $EUID -eq 0 ]] || { echo "run me with sudo:  sudo $0" >&2; exit 1; }

echo "[*] stopping any server on tcp/$PORT ..."
fuser -k "$PORT/tcp" 2>/dev/null || true
sleep 0.3

# clears "inet defense" (+ legacy round3) - single source of truth for table names
if [[ -x "$SCRIPT_DIR/firewall/flush.sh" ]]; then
    echo "[*] removing firewall defense ..."
    "$SCRIPT_DIR/firewall/flush.sh"
fi

echo "[*] restoring secure kernel defaults ..."
sysctl -qw net.ipv4.tcp_syncookies=1
sysctl -qw net.ipv4.tcp_max_syn_backlog=256

echo
echo "[+] done. Server stopped, defense removed, syncookies back on."
