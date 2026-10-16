
#!/usr/bin/env bash
#
# flush.sh - remove the defense and restore the vulnerable baseline
# so the next demo round is fragile again.
#
# Usage:  sudo ./flush.sh
#
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "run me with sudo" >&2
    exit 1
fi

echo "[*] removing nftables tables ..."
for t in defense round3; do
    if nft delete table inet "$t" 2>/dev/null; then
        echo "    deleted inet $t"
    fi
done

echo "[*] restoring conntrack default (tcp_loose=1) ..."
sysctl -qw net.netfilter.nf_conntrack_tcp_loose=1 2>/dev/null || true

echo "[*] restoring deliberately-fragile baseline ..."
sysctl -qw net.ipv4.tcp_syncookies=0
sysctl -qw net.ipv4.tcp_max_syn_backlog=128

echo
echo "[+] Baseline restored:"
sysctl net.ipv4.tcp_syncookies net.ipv4.tcp_max_syn_backlog
