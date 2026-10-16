
#!/usr/bin/env bash
#
# round1.sh - apply the SAME-SOURCE-IP SYN-flood defense.
#             (bans the attacking source IP + rate-limits all sources)
#
# Always starts clean: it flushes any previous defense FIRST, so switching
# between rounds never leaves stale rules or sysctls behind.
#
# Usage:  sudo ./round1.sh
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
for m in nf_tables nf_conntrack; do
    if modprobe "$m" 2>/dev/null; then echo "    + $m"; else echo "    . $m (built-in or absent - ok)"; fi
done

echo "[*] syntax-checking round1.nft ..."
nft -c -f "$HERE/round1.nft"

echo "[*] applying Round 1 defense (block the attacking source IP) ..."
nft -f "$HERE/round1.nft"

echo
echo "[*] active:"
nft -a list chain inet defense input

echo
echo "[+] Round 1 defense is UP."
echo "    - bans the flooding source IP (stays banned until flush.sh)"
echo "    - caps every source at 20 SYN/s"
echo "    watch it work:  sudo $HERE/show.sh"
