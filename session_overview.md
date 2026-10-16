# CCSA Session 1: Operation SYN Flood (Red vs. Blue)

## 🎯 Session Objective
The goal of this session is to introduce members to a live Red Team vs. Blue Team environment. We will demonstrate a classic Denial of Service (DoS) attack—the **TCP SYN Flood**—and the modern network defenses used to stop it. Members will not just watch a presentation; they will actively crash a server and then learn how to patch it in real-time.

## 🏗️ Architecture & Setup
Our infrastructure is hosted on a centralized Proxmox (Type 1) server. Members connect their laptops to the club network via a Tailscale VPN. Once connected, they use SSH to access two distinct virtual machines:

*   **VM 1 (Red Team / Attack Box):** A Kali Linux jumpbox located in the `SERVICES` subnet.
*   **VM 2 (Blue Team / Target Box):** A vulnerable kali Linux server located in the `LAB` subnet, running a fragile web service.

## 🚀 The Scenario Flow

### Phase 1: The Baseline
The Blue Team connects to VM 2 and starts the fragile web service (`game.py`). Members open a browser to play the web-based Snake game. Everything is functioning normally, and CPU usage is at 0%.

### Phase 2: Round 1 Attack (Single-IP SYN Flood)
The Red Team uses a custom C program (`syn.c`) to unleash a massive flood of half-open TCP handshakes against the Target VM from their single IP address. 
*   **The Impact:** The web server's tiny connection queue fills instantly. The Snake game flashes an "OFFLINE" warning, and the browser freezes. 
*   **The Defense:** The Blue Team uses `tcpdump` to spot the incoming traffic, identifies the attacker's IP, and executes `round1.sh` to load an `nftables` rule that permanently bans the offending IP. The server instantly recovers.

### Phase 3: Round 2 Attack (Spoofed Multi-IP SYN Flood)
The Red Team adapts. They run `syn.c` in "spoofed" mode, which randomizes the source IP address for every single packet. 
*   **The Impact:** The Blue Team's previous static IP ban is rendered useless. Traffic appears to come from all over the world, and the server crashes again.
*   **The Defense:** The Blue Team cannot block individual IPs. They execute `round2.sh`, which deploys `synproxy`. This forces the Linux kernel firewall to complete the 3-way handshake on behalf of the web server, completely neutralizing the spoofed packets. The game comes back online for good.

