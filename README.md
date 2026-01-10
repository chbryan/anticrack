# Anticrack Gamma

Suite of advanced bash scripts to block major tech companies, countries, domains, IPs, services, tracking, and software on Linux systems. Prevents surveillance, adware, and asset operation from enemies like Russia, China, Iran, North Korea, Belarus, Syria, Venezuela, Cuba, Pakistan, Cambodia, Myanmar, Nicaragua, Eritrea, Mali, Central African Republic, Burkina Faso, Niger, Greenland, and groups like NATO, BRICS, as well as intelligence agencies (NSA, FBI, GCHQ, MI6) and tech giants (Google, Microsoft, Amazon, Meta, Apple, Netflix).

## Overview

`anticrack-gamma.sh`: The ultimate unified script, building on previous versions. Blocks enemy country IP ranges (IPv4/IPv6), DNS servers, domains (tech, social, media, military, foreign tech), TLDs (.ru, .cn, etc.), TOR/VPN exits, threats. Features include:

- Menu-driven interface for blocking/unblocking entities and groups (enemies, allies, all_enemies, NATO, Greenland, India, BRICS, tech, all).
- Domain/TLD/group management via `/etc/hosts` and dnsmasq.
- IP blocking via nftables.
- Package removal for blocked entities.
- Whitelisting for IPs/domains.
- Total lockdown mode with TOR exit/bridge blocking, rate limiting, logging, and integration with Fail2Ban, Suricata, Snort, CrowdSec, and UFW.
- TOR obfuscation using obfs4 bridges.
- Error handling, logging to `/var/log/anticrack.log`, and cron for daily updates.
- Restore and flush rules functionality.

Separate entity scripts are not included; all functionality is consolidated in the gamma version.

## Requirements

- Linux distribution (tested on Debian-based systems like Ubuntu).
- Root access.
- Dependencies: nftables, wget, netfilter-persistent, dnsmasq, fail2ban, suricata, curl, jq, tor, snort, crowdsec, crowdsec-firewall-bouncer-nftables, obfs4proxy, ufw.

Install dependencies by running the script (it handles installation), or manually:

```
sudo apt update
sudo apt install nftables wget netfilter-persistent dnsmasq fail2ban suricata curl jq tor snort crowdsec crowdsec-firewall-bouncer-nftables obfs4proxy ufw
```

For CrowdSec, the script adds the repository automatically.

## Usage

Run as root:

```
sudo ./anticrack-gamma.sh
```

This launches the interactive menu:

1. Block an entity (e.g., enter code like `ru` for Russia).
2. Block a group (e.g., `enemies`, `nato`).
3. Disable an entity.
4. Disable a group.
5. Show status (blocked entities, whitelist, nft rules, logs).
6. Total lockdown (blocks all groups, TOR, enables IDS/IPS, rate limiting).
7. Update lists (reapplies blocks with latest data).
8. Add whitelist (IP or domain).
9. Setup cron updates (daily refresh).
10. Enable TOR obfuscation (adds obfs4 bridges to torrc).
11. Integrate UFW (sets default deny incoming, allow outgoing and SSH).
12. Exit.

### Examples

- Block Russia: Choose option 1, enter `ru`.
- Total lockdown: Choose option 6 for maximum protection.
- Whitelist an IP: Choose option 8, enter e.g., `8.8.8.8`.

State is persisted in `/etc/anticrack/` (blocked.txt, whitelist.txt, backups).

## Warnings

- **Backup configurations**: The script backs up `/etc/hosts` and nft rules automatically, but always test in a VM first.
- **Potential disruption**: Blocking may break connectivity to services (e.g., tech giants). Use whitelist to allow exceptions.
- **Updates**: Run option 7 periodically or set up cron (option 9) to fetch latest IP/domain lists.
- **Conflicts**: UFW and nftables may interact; monitor for issues.
- **TOR**: Enabling obfuscation modifies `/etc/tor/torrc`; restart TOR manually if needed.
- **Logs**: Check `/var/log/anticrack.log` for errors and actions.

## License
GPL-3.0
