# VM 2: The Vulnerable Target Box (Blue Team)

## 🛡️ Overview
This virtual machine resides in the `LAB` subnet. It hosts a deliberately fragile web application designed to crash spectacularly under pressure. Blue Team members will SSH into this machine to monitor incoming traffic and deploy dynamic firewall defenses to keep the service alive.

## 🕸️ The Target Service
### `game.py`
**Purpose:** A custom, single-threaded Python web server hosting a playable HTML5 Snake game.
*   **The Vulnerability:** Unlike enterprise servers like Nginx, this script uses a custom `TCPServer` with an intentionally microscopic connection queue (`request_queue_size = 1`). 
*   **The Visuals:** It features a JavaScript heartbeat that constantly pings the server. When the SYN flood hits, the heartbeat fails, and the game screen flashes a bright red **"OFFLINE (SYN FLOOD DETECTED)"** warning, providing instant visual feedback to the room that the attack was successful.

## 🧱 The Defensive Arsenal

### 1. Round 1 Defense (`round1.sh` & `round1.nft`)
**Target:** Stops the single-IP attack.
*   **How it works:** The `round1.nft` script uses `nftables` to create a dynamic ban list. It monitors inbound SYN traffic on port 80. If a single IP sends more than 50 SYN packets per second, it is instantly added to the `@synflood` blocklist and dropped. It also applies a global rate limit of 20 SYN/s as a backstop.
*   **Execution:** `sudo ./round1.sh` flushes old rules and applies this defense.

### 2. Round 2 Defense (`round2.sh` & `round2.nft`)
**Target:** Stops the spoofed multi-IP attack.
*   **How it works:** When the attacker spoofs their IP, the per-source ban list in Round 1 fails. `round2.nft` introduces **SYNPROXY**. It tells the `raw` prerouting chain to stop tracking connection states for port 80. Then, the firewall itself answers the attacker's SYN packets with a SYN-ACK. The firewall only forwards the connection to `game.py` *if* the client replies with a valid final ACK (which spoofed IPs will never do). 
*   **Execution:** `sudo ./round2.sh` disables loose conntrack via `sysctl` and loads the advanced proxy rules, perfectly shielding the fragile game server from the flood.