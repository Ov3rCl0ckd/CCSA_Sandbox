
#!/usr/bin/env bash
#
# start_game.sh - one-shot bring-up for the CCSA fragile Snake demo.
#
#   sudo ./start_game.sh
#
# Frees tcp/80, drops any leftover defense, applies the deliberately-fragile
# kernel baseline, then runs game.py in the foreground (Ctrl-C to stop).
#
# See firewall/CHEATSHEET.md for the full demo run order.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME="$SCRIPT_DIR/game.py"
FLUSH="$SCRIPT_DIR/firewall/flush.sh"
HOST_IP="10.2.0.4"
PORT=80

[[ $EUID -eq 0 ]] || { echo "run me with sudo:  sudo $0" >&2; exit 1; }

say() { echo "[*] $*"; }
ok()  { echo "[+] $*"; }

# 0. sanity: the pieces we depend on must exist
[[ -f $GAME ]]                 || { echo "!! game.py not found at $GAME" >&2; exit 1; }
command -v python3 >/dev/null  || { echo "!! python3 not installed" >&2; exit 1; }
if ! ip -4 addr show | grep -qw "$HOST_IP"; then
    echo "!! $HOST_IP is not up on this machine - game.py cannot bind it" >&2
    exit 1
fi

# 1. nginx must not hold the port (this is what broke the last manual start)
if systemctl is-active --quiet nginx 2>/dev/null; then
    say "stopping nginx (it was holding tcp/$PORT)"
    systemctl stop nginx
fi

# 2. no leftover defense from the previous session
if [[ -x $FLUSH ]]; then
    say "flushing leftover nftables defense"
    "$FLUSH"
fi

# 3. deliberately-fragile kernel baseline (flush.sh sets this too; explicit = safe).
#    NOTE: not persistent - re-applied here on every start, so the VM stays
#    normal across reboots when the lab is not running.
say "applying deliberately-fragile kernel baseline"
sysctl -qw net.ipv4.tcp_syncookies=0
sysctl -qw net.ipv4.tcp_max_syn_backlog=128

# 4. kill any stale listener / old server instance
say "freeing tcp/$PORT"
fuser -k "$PORT/tcp" 2>/dev/null || true
sleep 0.3

# 5. verify the port is actually free BEFORE exec'ing - fail loudly, not silently
if ss -ltn "sport = :$PORT" 2>/dev/null | tail -n +2 | grep -q .; then
    echo "!! tcp/$PORT is still in use - someone else owns it:" >&2
    ss -ltnp "sport = :$PORT" >&2
    echo "   stop the holder (nginx? old game.py?) and retry" >&2
    exit 1
fi

ok "tcp/$PORT free, baseline applied"
echo "[+] browse to  http://$HOST_IP/   (Ctrl-C to stop the server)"
echo

exec python3 "$GAME"
