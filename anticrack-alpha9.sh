#!/bin/bash

set -euo pipefail  # Strict mode for error handling

if [ "$(id -u)" != "0" ]; then
   echo "Run as root." 1>&2
   exit 1
fi

# Install dependencies
function install_dependencies() {
  apt update -y || { echo "apt update failed."; exit 1; }
  apt install -y ipset wget iptables-persistent dnsmasq fail2ban suricata curl jq tor snort || { echo "Installation failed."; exit 1; }
}

install_dependencies

# Country mappings
declare -A country_names
country_names=(
  [cn]="China" [ru]="Russia" [ir]="Iran" [kp]="North Korea" [by]="Belarus" [sy]="Syria" [ve]="Venezuela" [cu]="Cuba" [pk]="Pakistan" [kh]="Cambodia" [mm]="Myanmar" [ni]="Nicaragua" [er]="Eritrea" [ml]="Mali" [cf]="Central African Republic" [bf]="Burkina Faso" [ne]="Niger" [gl]="Greenland"
  [al]="Albania" [be]="Belgium" [bg]="Bulgaria" [ca]="Canada" [hr]="Croatia" [cz]="Czech Republic" [dk]="Denmark" [ee]="Estonia" [fi]="Finland" [fr]="France" [de]="Germany" [gr]="Greece" [hu]="Hungary" [is]="Iceland" [it]="Italy" [lv]="Latvia" [lt]="Lithuania" [lu]="Luxembourg" [me]="Montenegro" [nl]="Netherlands" [mk]="North Macedonia" [no]="Norway" [pl]="Poland" [pt]="Portugal" [ro]="Romania" [sk]="Slovakia" [si]="Slovenia" [es]="Spain" [se]="Sweden" [tr]="Turkey" [gb]="United Kingdom" [us]="United States" [in]="India"
)

countries=(cn ru ir kp by sy ve cu pk kh mm ni er ml cf bf ne gl al be bg ca hr cz dk ee fi fr de gr hu is it lv lt lu me nl mk no pl pt ro sk si es se tr gb us in)

# Predefined country groups
declare -A country_groups
country_groups[enemies]="ru cn ir ve kp gl"
country_groups[allies]="by sy cu pk kh mm ni er ml cf bf ne"
country_groups[all_enemies]="ru cn ir ve kp gl by sy cu pk kh mm ni er ml cf bf ne"
country_groups[nato]="al be bg ca hr cz dk ee fi fr de gr hu is it lv lt lu me nl mk no pl pt ro sk si es se tr gb us"
country_groups[greenland]="gl"
country_groups[india]="in"

# Enemy DNS IPs
dns_ips=( # ... [truncated for brevity, same as before] )

# Enemy DNS IPv6
dns_ipv6_ips=( # ... [truncated] )

# Domain lists
us_tech_domains=("google.com" "youtube.com" "facebook.com" "instagram.com" "amazon.com" "microsoft.com" "apple.com" "netflix.com" "x.com" "tiktok.com" "whatsapp.com" "linkedin.com" "yahoo.com")

foreign_tech_domains=("baidu.com" "yandex.ru" "alibaba.com" "tencent.com" "huawei.com" "bytedance.com" "mi.com" "jd.com" "meituan.com" "pinduoduo.com" "didiglobal.com" "smics.com" "sensetime.com" "kaspersky.com" "1c.ru" "wildberries.ru" "ozon.ru" "digikala.com" "snapp.ir" "cafebazaar.ir" "epam.com" "iba.by" "wargaming.com" "systemsltd.com" "netsoltech.com" "confiz.com" "trgworld.com" "ibex.co" "tkxel.com" "10pearls.com" "ezecom.com.kh" "sinet.com.kh" "frontiir.com" "wavemoney.com.mm" "oway.com.mm" "infosys.com" "tcs.com" "wipro.com" "hcltech.com" "techmahindra.com" "zoho.com" "paytm.com" "flipkart.com" "ola.com" "byjus.com" "phonepe.com" "swiggy.com" "makemytrip.com" "freshworks.com" "postman.com")

enemy_social_domains=( # ... [same] )

enemy_media_domains=( # ... [same] )

military_domains=( # ... [same] )

# Optimized domain groups
declare -A domain_groups
domain_groups[us_tech]="${us_tech_domains[*]}"
domain_groups[foreign_tech]="${foreign_tech_domains[*]}"
domain_groups[enemy_social]="${enemy_social_domains[*]}"
domain_groups[enemy_media]="${enemy_media_domains[*]}"
domain_groups[military]="${military_domains[*]}"

DNSMASQ_CONF="/etc/dnsmasq.d/blocked-domains.conf"
HOSTS_FILE="/etc/hosts"
BLOCK_MARKER="# AntiCrack Block"
BLOCKED_DOMAINS_FILE="/tmp/anticrack_domains.txt"
THREAT_LIST_URL="https://feodotracker.abuse.ch/downloads/ipblocklist.txt"
TOR_EXIT_URL="https://www.dan.me.uk/torlist/?exit"
VPN_LIST_URL="https://raw.githubusercontent.com/X4BNet/lists_vpn/main/ipv4.txt"
IPTABLES_BACKUP="/etc/iptables.backup.rules"
IP6TABLES_BACKUP="/etc/ip6tables.backup.rules"

# Safety: Backup rules before changes
function backup_rules() {
  iptables-save > "$IPTABLES_BACKUP"
  ip6tables-save > "$IP6TABLES_BACKUP"
  echo "Rules backed up."
}

# Check command execution
function check_command() {
  "$@" || { echo "Command failed: $*"; exit 1; }
}

# Country block status
function status_country() {
  ipset list "block-$1" >/dev/null 2>&1 && echo "Enabled" || echo "Disabled"
}

# Enable country block
function enable_country() {
  local c=$1
  backup_rules
  read -p "Confirm enable ${country_names[$c]}? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [ "$(status_country $c)" == "Enabled" ]; then
    echo "${country_names[$c]} already enabled."
    return
  fi
  check_command wget -q "https://www.ipdeny.com/ipblocks/data/aggregated/${c}-aggregated.zone" -O "/tmp/${c}.zone"
  check_command wget -q "https://www.ipdeny.com/ipv6/ipaddresses/aggregated/${c}-aggregated.zone" -O "/tmp/${c}-v6.zone"
  check_command ipset create "block-$c" hash:net family inet
  check_command ipset create "block-${c}-v6" hash:net family inet6
  while IFS= read -r ip; do
    [ -n "$ip" ] && ipset add "block-$c" "$ip" 2>/dev/null
  done < "/tmp/${c}.zone"
  while IFS= read -r ip; do
    [ -n "$ip" ] && ipset add "block-${c}-v6" "$ip" 2>/dev/null
  done < "/tmp/${c}-v6.zone"
  rm -f "/tmp/${c}.zone" "/tmp/${c}-v6.zone"
  iptables -A INPUT -m set --match-set "block-$c" src -j DROP 2>/dev/null || true
  iptables -A OUTPUT -m set --match-set "block-$c" dst -j DROP 2>/dev/null || true
  ip6tables -A INPUT -m set --match-set "block-${c}-v6" src -j DROP 2>/dev/null || true
  ip6tables -A OUTPUT -m set --match-set "block-${c}-v6" dst -j DROP 2>/dev/null || true
  echo "${country_names[$c]} enabled."
}

# Disable country block
function disable_country() {
  local c=$1
  backup_rules
  read -p "Confirm disable ${country_names[$c]}? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [ "$(status_country $c)" == "Disabled" ]; then
    echo "${country_names[$c]} already disabled."
    return
  fi
  iptables -D INPUT -m set --match-set "block-$c" src -j DROP 2>/dev/null || true
  iptables -D OUTPUT -m set --match-set "block-$c" dst -j DROP 2>/dev/null || true
  ip6tables -D INPUT -m set --match-set "block-${c}-v6" src -j DROP 2>/dev/null || true
  ip6tables -D OUTPUT -m set --match-set "block-${c}-v6" dst -j DROP 2>/dev/null || true
  ipset destroy "block-$c" 2>/dev/null || true
  ipset destroy "block-${c}-v6" 2>/dev/null || true
  echo "${country_names[$c]} disabled."
}

# Enable country group
function enable_country_group() {
  local g=$1
  for c in ${country_groups[$g]}; do
    enable_country $c
  done
  echo "$g group enabled."
}

# Disable country group
function disable_country_group() {
  local g=$1
  for c in ${country_groups[$g]}; do
    disable_country $c
  done
  echo "$g group disabled."
}

# Create custom country group
function create_custom_country_group() {
  read -p "Custom group name: " group
  if [[ -n "${country_groups[$group]}" ]]; then
    echo "Group exists."
    return
  fi
  echo "Enter countries (format: 'Country: code, ...')"
  read -p "Countries: " input
  codes=$(echo "$input" | sed 's/[^:]*: \([a-z][a-z]\),*/\1 /g') || { echo "Invalid."; return; }
  country_groups[$group]="$codes"
  echo "Custom group $group created: $codes"
}

# DNS block status
function status_dns_block() {
  ipset list block-dns >/dev/null 2>&1 && echo "Enabled" || echo "Disabled"
}

# Enable DNS block
function enable_dns_block() {
  backup_rules
  read -p "Confirm enable DNS block? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [ "$(status_dns_block)" == "Enabled" ]; then
    echo "DNS block enabled."
    return
  fi
  ipset create block-dns hash:ip family inet 2>/dev/null
  for ip in "${dns_ips[@]}"; do
    ipset add block-dns "$ip" 2>/dev/null
  done
  ipset create block-dns6 hash:ip family inet6 2>/dev/null
  for ip in "${dns_ipv6_ips[@]}"; do
    ipset add block-dns6 "$ip" 2>/dev/null
  done
  iptables -A INPUT -m set --match-set block-dns src -j DROP 2>/dev/null || true
  iptables -A OUTPUT -m set --match-set block-dns dst -j DROP 2>/dev/null || true
  ip6tables -A INPUT -m set --match-set block-dns6 src -j DROP 2>/dev/null || true
  ip6tables -A OUTPUT -m set --match-set block-dns6 dst -j DROP 2>/dev/null || true
  echo "DNS block enabled."
}

# Disable DNS block
function disable_dns_block() {
  backup_rules
  read -p "Confirm disable DNS block? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [ "$(status_dns_block)" == "Disabled" ]; then
    echo "DNS block disabled."
    return
  fi
  iptables -D INPUT -m set --match-set block-dns src -j DROP 2>/dev/null || true
  iptables -D OUTPUT -m set --match-set block-dns dst -j DROP 2>/dev/null || true
  ip6tables -D INPUT -m set --match-set block-dns6 src -j DROP 2>/dev/null || true
  ip6tables -D OUTPUT -m set --match-set block-dns6 dst -j DROP 2>/dev/null || true
  ipset destroy block-dns 2>/dev/null || true
  ipset destroy block-dns6 2>/dev/null || true
  echo "DNS block disabled."
}

# Enable domain group
function enable_domain_group() {
  local g=$1
  backup_rules
  read -p "Confirm enable $g group? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  for d in ${domain_groups[$g]}; do
    block_domain "$d"
  done
  echo "$g group enabled."
}

# Disable domain group
function disable_domain_group() {
  local g=$1
  backup_rules
  read -p "Confirm disable $g group? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  for d in ${domain_groups[$g]}; do
    unblock_domain "$d"
  done
  echo "$g group disabled."
}

# Domain group status
function status_domain_group() {
  local g=$1
  local blocked=0
  local total=0
  for d in ${domain_groups[$g]}; do
    ((total++))
    [ "$(status_domain $d)" == "Blocked" ] && ((blocked++))
  done
  if [ $blocked -eq $total ]; then
    echo "Enabled"
  elif [ $blocked -eq 0 ]; then
    echo "Disabled"
  else
    echo "Partial ($blocked/$total)"
  fi
}

# Create custom domain group
function create_custom_domain_group() {
  read -p "Custom domain group name: " group
  if [[ -n "${domain_groups[$group]}" ]]; then
    echo "Group exists."
    return
  fi
  echo "Enter domains (space-separated)"
  read -p "Domains: " domains
  domain_groups[$group]="$domains"
  echo "Custom group $group created: $domains"
}

# Total lockdown
function total_lockdown() {
  backup_rules
  read -p "Confirm total lockdown? This blocks extensively (y/n): " confirm
  [ "$confirm" != "y" ] && return
  enable_country_group all_enemies
  enable_dns_block
  enable_domain_group us_tech
  enable_domain_group foreign_tech
  enable_domain_group enemy_social
  enable_domain_group enemy_media
  enable_domain_group military
  enable_fail2ban
  enable_suricata
  enable_snort
  enable_tor_block
  enable_vpn_block
  update_threat_lists
  enable_rate_limiting
  echo "Total lockdown enabled."
}

# List status
function list_status() {
  echo "Countries:"
  for c in "${countries[@]}"; do
    echo "${country_names[$c]} ($c): $(status_country $c)"
  done
  echo "DNS Block: $(status_dns_block)"
  echo "US Tech: $(status_domain_group us_tech)"
  echo "Foreign Tech: $(status_domain_group foreign_tech)"
  echo "Enemy Social: $(status_domain_group enemy_social)"
  echo "Enemy Media: $(status_domain_group enemy_media)"
  echo "Military: $(status_domain_group military)"
  echo "Fail2Ban: $(systemctl is-active fail2ban)"
  echo "Suricata: $(systemctl is-active suricata)"
  echo "Snort: $(systemctl is-active snort)"
  echo "TOR Block: $(ipset list block-tor >/dev/null 2>&1 && echo Enabled || echo Disabled)"
  echo "VPN Block: $(ipset list block-vpn >/dev/null 2>&1 && echo Enabled || echo Disabled)"
  echo "Rate Limiting: $(iptables -L | grep 'limit' >/dev/null && echo Enabled || echo Disabled)"
}

# Domain status
function status_domain() {
  local d=$1
  grep -q "^0.0.0.0 $d $BLOCK_MARKER" "$HOSTS_FILE" && echo "Blocked (hosts)" || (grep -q "/.$d/" "$DNSMASQ_CONF" && echo "Blocked (dnsmasq)" || echo "Not blocked")
}

# Block domain
function block_domain() {
  local d=$1
  backup_rules
  read -p "Confirm block $d? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [[ "$d" == *'*'* ]]; then
    d=${d/\*/}
    if grep -q "/.$d/" "$DNSMASQ_CONF"; then
      echo "$d blocked."
      return
    fi
    echo "address=/.$d/0.0.0.0" >> "$DNSMASQ_CONF"
    systemctl restart dnsmasq
    echo "$d wildcard blocked."
  else
    if [ "$(status_domain $d)" == "Blocked (hosts)" ]; then
      echo "$d blocked."
      return
    fi
    echo "0.0.0.0 $d $BLOCK_MARKER" >> "$HOSTS_FILE"
    echo "0.0.0.0 www.$d $BLOCK_MARKER" >> "$HOSTS_FILE"
    echo "$d blocked."
  fi
}

# Unblock domain
function unblock_domain() {
  local d=$1
  backup_rules
  read -p "Confirm unblock $d? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [[ "$d" == *'*'* ]]; then
    d=${d/\*/}
    sed -i "/\/.$d\//d" "$DNSMASQ_CONF"
    systemctl restart dnsmasq
    echo "$d wildcard unblocked."
  else
    sed -i "/^0.0.0.0 $d $BLOCK_MARKER/d" "$HOSTS_FILE"
    sed -i "/^0.0.0.0 www.$d $BLOCK_MARKER/d" "$HOSTS_FILE"
    echo "$d unblocked."
  fi
}

# List blocked domains
function list_blocked_domains() {
  grep "$BLOCK_MARKER" "$HOSTS_FILE" | awk '{print $2 " (hosts)"}' > "$BLOCKED_DOMAINS_FILE"
  grep "address=" "$DNSMASQ_CONF" | awk -F'/' '{print "*." $2 " (dnsmasq)"}' >> "$BLOCKED_DOMAINS_FILE"
  if [ -s "$BLOCKED_DOMAINS_FILE" ]; then
    cat "$BLOCKED_DOMAINS_FILE"
  else
    echo "No domains blocked."
  fi
  rm -f "$BLOCKED_DOMAINS_FILE"
}

# Enable logging
function enable_logging() {
  backup_rules
  iptables -A INPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  iptables -A OUTPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  ip6tables -A INPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  ip6tables -A OUTPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  echo "Logging enabled."
}

# Disable logging
function disable_logging() {
  backup_rules
  iptables -D INPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  iptables -D OUTPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  ip6tables -D INPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  ip6tables -D OUTPUT -j LOG --log-prefix "AntiCrack DROP: " 2>/dev/null || true
  echo "Logging disabled."
}

# Flush rules
function flush_rules() {
  backup_rules
  read -p "Confirm flush all rules? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  iptables -F
  iptables -X
  ip6tables -F
  ip6tables -X
  for set in $(ipset list -name); do ipset destroy $set 2>/dev/null; done
  echo "Rules flushed."
}

# Restore rules from backup
function restore_rules() {
  read -p "Confirm restore from backup? (y/n): " confirm
  [ "$confirm" != "y" ] && return
  if [ -f "$IPTABLES_BACKUP" ]; then
    iptables-restore < "$IPTABLES_BACKUP"
  else
    echo "No iptables backup."
  fi
  if [ -f "$IP6TABLES_BACKUP" ]; then
    ip6tables-restore < "$IP6TABLES_BACKUP"
  else
    echo "No ip6tables backup."
  fi
  echo "Rules restored."
}

# Enable Fail2Ban
function enable_fail2ban() {
  # ... [same as before, truncated for brevity]
}

# Disable Fail2Ban
function disable_fail2ban() {
  # ... [same]
}

# Enable Suricata
function enable_suricata() {
  # ... [same]
}

# Disable Suricata
function disable_suricata() {
  # ... [same]
}

# Enable Snort
function enable_snort() {
  # ... [same]
}

# Disable Snort
function disable_snort() {
  # ... [same]
}

# Update threat lists
function update_threat_lists() {
  # ... [same]
}

# Enable TOR block
function enable_tor_block() {
  # ... [same]
}

# Disable TOR block
function disable_tor_block() {
  # ... [same]
}

# Enable VPN block
function enable_vpn_block() {
  # ... [same]
}

# Disable VPN block
function disable_vpn_block() {
  # ... [same]
}

# Enable rate limiting
function enable_rate_limiting() {
  # ... [same]
}

# Disable rate limiting
function disable_rate_limiting() {
  # ... [same]
}

# List countries
function list_countries() {
  for c in "${!country_names[@]}"; do
    echo "${country_names[$c]}: $c"
  done
}

echo "AntiCrack Blocker - Efficient defensive tool."
echo "Warning: Backup data before use. May disrupt services."
echo "Available countries:"
list_countries

while true; do
  echo "1) List status"
  echo "2) Enable country"
  echo "3) Disable country"
  echo "4) Country status"
  echo "5) Enable country group"
  echo "6) Disable country group"
  echo "7) List blocked domains"
  echo "8) Block domain"
  echo "9) Unblock domain"
  echo "10) Domain status"
  echo "11) Enable DNS block"
  echo "12) Disable DNS block"
  echo "13) DNS block status"
  echo "14) Enable domain group"
  echo "15) Disable domain group"
  echo "16) Domain group status"
  echo "17) Create custom country group"
  echo "18) Create custom domain group"
  echo "19) Enable logging"
  echo "20) Disable logging"
  echo "21) Flush rules"
  echo "22) Restore rules"
  echo "23) Total lockdown"
  echo "24) Enable Fail2Ban"
  echo "25) Disable Fail2Ban"
  echo "26) Enable Suricata"
  echo "27) Disable Suricata"
  echo "28) Update threat lists"
  echo "29) Enable TOR block"
  echo "30) Disable TOR block"
  echo "31) Enable VPN block"
  echo "32) Disable VPN block"
  echo "33) Enable rate limiting"
  echo "34) Disable rate limiting"
  echo "35) Enable Snort"
  echo "36) Disable Snort"
  echo "37) Exit"
  read -p "Choice: " choice
  case $choice in
    1) list_status ;;
    2) read -p "Code: " code; [[ " ${countries[*]} " =~ " ${code} " ]] && enable_country $code || echo "Invalid." ;;
    3) read -p "Code: " code; [[ " ${countries[*]} " =~ " ${code} " ]] && disable_country $code || echo "Invalid." ;;
    4) read -p "Code: " code; [[ " ${countries[*]} " =~ " ${code} " ]] && echo "${country_names[$code]}: $(status_country $code)" || echo "Invalid." ;;
    5) read -p "Group: " group; [[ -n "${country_groups[$group]}" ]] && enable_country_group $group || echo "Invalid." ;;
    6) read -p "Group: " group; [[ -n "${country_groups[$group]}" ]] && disable_country_group $group || echo "Invalid." ;;
    7) list_blocked_domains ;;
    8) read -p "Domain: " domain; [[ -n "$domain" ]] && block_domain $domain || echo "Invalid." ;;
    9) read -p "Domain: " domain; [[ -n "$domain" ]] && unblock_domain $domain || echo "Invalid." ;;
    10) read -p "Domain: " domain; [[ -n "$domain" ]] && echo "$domain: $(status_domain $domain)" || echo "Invalid." ;;
    11) enable_dns_block ;;
    12) disable_dns_block ;;
    13) echo "DNS Block: $(status_dns_block)" ;;
    14) read -p "Group: " group; [[ -n "${domain_groups[$group]}" ]] && enable_domain_group $group || echo "Invalid." ;;
    15) read -p "Group: " group; [[ -n "${domain_groups[$group]}" ]] && disable_domain_group $group || echo "Invalid." ;;
    16) read -p "Group: " group; [[ -n "${domain_groups[$group]}" ]] && echo "$group: $(status_domain_group $group)" || echo "Invalid." ;;
    17) create_custom_country_group ;;
    18) create_custom_domain_group ;;
    19) enable_logging ;;
    20) disable_logging ;;
    21) flush_rules ;;
    22) restore_rules ;;
    23) total_lockdown ;;
    24) enable_fail2ban ;;
    25) disable_fail2ban ;;
    26) enable_suricata ;;
    27) disable_suricata ;;
    28) update_threat_lists ;;
    29) enable_tor_block ;;
    30) disable_tor_block ;;
    31) enable_vpn_block ;;
    32) disable_vpn_block ;;
    33) enable_rate_limiting ;;
    34) disable_rate_limiting ;;
    35) enable_snort ;;
    36) disable_snort ;;
    37) read -p "Save rules? (y/n): " save; [ "$save" == "y" ] && { iptables-save > /etc/iptables.rules; ip6tables-save > /etc/ip6tables.rules; echo "Saved."; }; exit 0 ;;
    *) echo "Invalid." ;;
  esac
done
