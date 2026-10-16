
#!/usr/bin/env bash
#
# show.sh - live view of the defense for the projector.
#
# Usage:  sudo ./show.sh
#         watch -n1 sudo ./show.sh
#
if [[ $EUID -ne 0 ]]; then
    echo "run me with sudo" >&2
    exit 1
fi

T=defense

echo "==================== nftables rules + counters ===================="
nft -a list table inet "$T" 2>/dev/null || echo "(table inet $T not loaded)"

echo
echo "==================== ban list (@synflood) =========================="
nft list set inet "$T" synflood 2>/dev/null || echo "(no set / table not loaded)"

echo
echo "==================== kernel handshake knobs ========================"
sysctl net.ipv4.tcp_syncookies net.ipv4.tcp_max_syn_backlog net.netfilter.nf_conntrack_tcp_loose 2>/dev/null \
    || sysctl net.ipv4.tcp_syncookies net.ipv4.tcp_max_syn_backlog

echo
echo "==================== half-open connections ========================="
echo -n "SYN-RECV (state 03): "; awk '$4=="03"{n++} END{print n+0}' /proc/net/tcp
echo -n "ESTABLISHED (state 01): "; awk '$4=="01"{n++} END{print n+0}' /proc/net/tcp

echo
echo "==================== synproxy / conntrack modules =================="
lsmod | grep -E 'synproxy|conntrack' || echo "(modules not loaded)"
