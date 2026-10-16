
#!/usr/bin/env bash
#
# round2.sh - apply Round 1 PLUS synproxy, to defeat SPOOFED source IPs.
#
# Always starts clean: it flushes any previous defense FIRST, so switching
# between rounds never leaves stale rules or sysctls behind.
#
# Usage:  sudo ./round2.sh
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

if [[ $EUID -ne 0 ]]; then
    echo "run me with sudo" >&2
    exit 1
fi

# --- clean slate: undo any previous round ---
echo "[*] flushing previous defense (restores vulnerable baseline) ..."
"$HERE/flush.sh"

echo "[*] loading kernel modules ..."
for m in nf_tables nf_conntrack nf_synproxy_core nft_synproxy; do
    if modprobe "$m" 2>/dev/null; then echo "    + $m"; else echo "    . $m (built-in or absent - ok)"; fi
done

# synproxy only works when conntrack loose mode is disabled
echo "[*] enabling synproxy requirement (nf_conntrack_tcp_loose=0) ..."
sysctl -qw net.netfilter.nf_conntrack_tcp_loose=0

echo "[*] syntax-checking round2.nft ..."
nft -c -f "$HERE/round2.nft"

echo "[*] applying Round 2 defense (same-IP ban + synproxy) ..."
nft -f "$HERE/round2.nft"

echo
echo "[*] active:"
nft -a list chain inet defense input
echo
nft -a list chain inet defense raw_prerouting

echo
echo "[+] Round 2 defense is UP."
echo "    - Round 1 same-IP ban/rate-limit is still in place"
echo "    - synproxy completes the handshake itself, so spoofed SYNs never"
echo "      reach game.py's listen backlog"
echo "    watch it work:  sudo $HERE/show.sh"
