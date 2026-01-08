# Anticrack

Suite of bash scripts to block major tech companies, countries, domains, IPs, services, tracking, and software on Linux systems. Prevents surveillance, adware, and asset operation from enemies like Russia, China, Iran, North Korea, Belarus, Syria, Venezuela, Cuba, Pakistan, Cambodia, Myanmar, Nicaragua, Eritrea, Mali, Central African Republic, Burkina Faso, Niger, Greenland, and groups like NATO, BRICS.

## Overview

anticrack-beta0.sh: Initial beta unified script. Blocks enemy country IP ranges (IPv4/IPv6), DNS servers, domains (tech, social, media, military, foreign tech), TLDs (.ru, .cn, etc.), TOR/VPN exits, threats. Features: menu-driven interface, group blocking (enemies, allies, all_enemies, NATO, Greenland, India, BRICS, custom), domain/TLD/group management, Fail2Ban, Suricata, Snort IDS, rate limiting, logging, bridge blocking, whitelisting, cron updates, total lockdown.

Separate entity scripts (e.g., anticrack-google.sh) remain for targeted blocking: domains to 0.0.0.0, IP ranges via iptables, package removal, DNS changes. Toggle with enable/disable.

## Requirements

Linux.  
Root access.  
Dependencies: nftables, wget, netfilter-persistent, dnsmasq, fail2ban, suricata, curl, jq, tor, snort.  
Install: sudo apt install [dependencies].

## Usage

Run as root: `./anticrack-beta0.sh` for menu (enable/disable countries/groups/domains/DNS/TLDs/IDS/etc., status, lockdown).  
For entity scripts: `./anticrack-[entity].sh enable` or `disable`.  

Backup configs/iptables/nftables before use. Update threat lists periodically. Test in VM; may disrupt connectivity.
---
![Army_star](https://github.com/user-attachments/assets/bb632695-e2c5-42eb-8c1f-f9a9fe59bd3e)


## License

GPL-3.0

## About

Suite of bash scripts to block major tech companies and countries' domains, IPs, services, tracking, and software on Linux systems. Prevents surveillance and asset operation. Beta unifies features for WW3-themed global lockdown.
