#!/bin/bash

set -euo pipefail # Strict mode for error handling

if [ "$(id -u)" != "0" ]; then
   echo "Run as root." 1>&2
   exit 1
fi

# Install dependencies
function install_dependencies() {
  apt update -y || { echo "apt update failed."; exit 1; }
  apt install -y curl gnupg lsb-release software-properties-common || { echo "Installation of prerequisites failed."; exit 1; }
  curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash || { echo "Adding CrowdSec repo failed."; exit 1; }
  apt update -y
  apt install -y nftables wget netfilter-persistent dnsmasq fail2ban suricata curl jq tor snort crowdsec crowdsec-firewall-bouncer-nftables || { echo "Installation failed."; exit 1; }
}

install_dependencies

# Directories and files
STATE_DIR="/etc/anticrack"
BLOCKED_FILE="$STATE_DIR/blocked.txt"
WHITELIST_FILE="$STATE_DIR/whitelist.txt"
HOSTS_FILE="/etc/hosts"
HOSTS_BACKUP="$STATE_DIR/hosts.bak"
NFT_BACKUP="$STATE_DIR/nft.bak"
DNSMASQ_CONF="/etc/dnsmasq.d/anticrack.conf"
LOG_FILE="/var/log/anticrack.log"

mkdir -p $STATE_DIR

# Entity names mapping
declare -A entity_names
entity_names=( [cn]="China" [ru]="Russia" [ir]="Iran" [kp]="North Korea" [by]="Belarus" [sy]="Syria" [ve]="Venezuela" [cu]="Cuba" [pk]="Pakistan" [kh]="Cambodia" [mm]="Myanmar" [ni]="Nicaragua" [er]="Eritrea" [ml]="Mali" [cf]="Central African Republic" [bf]="Burkina Faso" [ne]="Niger" [gl]="Greenland"
[al]="Albania" [be]="Belgium" [bg]="Bulgaria" [ca]="Canada" [hr]="Croatia" [cz]="Czech Republic" [dk]="Denmark" [ee]="Estonia" [fi]="Finland" [fr]="France" [de]="Germany" [gr]="Greece" [hu]="Hungary" [is]="Iceland" [it]="Italy" [lv]="Latvia" [lt]="Lithuania" [lu]="Luxembourg" [me]="Montenegro" [nl]="Netherlands" [mk]="North Macedonia" [no]="Norway" [pl]="Poland" [pt]="Portugal" [ro]="Romania" [sk]="Slovakia" [si]="Slovenia" [es]="Spain" [se]="Sweden" [tr]="Turkey" [gb]="United Kingdom" [us]="United States" [in]="India" [br]="Brazil" [za]="South Africa" [ua]="Ukraine" [nsa]="NSA" [fbi]="FBI" [gchq]="GCHQ" [mi6]="MI6"
[go]="Google" [ms]="Microsoft" [am]="Amazon" [me]="Meta" [ap]="Apple" [nf]="Netflix" )

entities=(cn ru ir kp by sy ve cu pk kh mm ni er ml cf bf ne gl al be bg ca hr cz dk ee fi fr de gr hu is it lv lt lu me nl mk no pl pt ro sk si es se tr gb us in br za ua nsa fbi gchq mi6 go ms am me ap nf)

# Predefined groups for blocking
declare -A groups
groups[enemies]="ru cn ir ve kp gl"
groups[allies]="by sy cu pk kh mm ni er ml cf bf ne"
groups[all_enemies]="ru cn ir ve kp gl by sy cu pk kh mm ni er ml cf bf ne nsa fbi gchq mi6"
groups[nato]="al be bg ca hr cz dk ee fi fr de gr hu is it lv lt lu me nl mk no pl pt ro sk si es se tr gb us"
groups[greenland]="gl"
groups[india]="in"
groups[brics]="br ru in cn za"
groups[tech]="go ms am me ap nf"
groups[all]="all_enemies nato tech"

# NSA/FBI/GCHQ/MI6 IP ranges
nsa_ips=("7.0.0.0/8" "11.0.0.0/8" "21.0.0.0/8" "22.0.0.0/8" "26.0.0.0/8" "28.0.0.0/8" "29.0.0.0/8" "30.0.0.0/8" "55.0.0.0/8" "214.0.0.0/8" "215.0.0.0/8")
fbi_ips=("153.31.0.0/16" "149.101.0.0/16")
gchq_ips=("25.0.0.0/8")
mi6_ips=("195.59.0.0/16")

# TOR Directory Authorities IPs (for bridge blocking feature)
tor_da_ips=("128.31.0.39" "45.66.33.45" "131.188.40.189" "193.23.244.244" "171.25.193.9" "154.35.175.225" "199.58.81.140" "204.13.164.118" "66.111.2.131" "37.218.245.14")

# Enemy DNS IPs
dns_ips=(
# China
"202.46.34.74" "202.46.34.76" "114.114.115.119" "114.114.114.114" "114.114.115.115" "202.46.33.250" "103.251.105.188" "1.12.13.53" "121.4.4.41" "103.144.53.209" "223.6.6.199" "223.5.5.17" "103.144.53.104" "120.53.53.84" "223.6.6.198" "223.5.5.219" "140.210.69.173" "223.6.6.141" "223.6.6.56" "103.251.106.105" "103.144.52.233" "223.6.6.72" "120.53.53.116" "223.5.5.51" "223.6.6.46" "223.5.5.190" "120.53.53.183" "223.6.6.169" "223.6.6.195" "103.144.52.214" "223.5.5.224" "173.82.141.168" "223.5.5.111" "223.6.6.6" "120.53.53.54" "223.6.6.17" "120.53.53.198" "202.46.34.75" "103.144.52.240" "223.6.6.204" "223.5.5.228" "223.6.6.127" "223.5.5.148" "223.6.6.133" "121.4.4.246" "223.5.5.187" "223.5.5.123" "223.5.5.82" "223.6.6.139" "223.5.5.79"
# Russia
"77.88.8.1" "77.88.8.3" "77.88.8.88" "94.158.96.2" "92.223.65.71" "194.67.109.176" "195.112.96.34" "195.208.5.1" "89.250.221.106" "93.157.172.153" "5.44.54.106" "94.180.111.233" "178.161.150.190" "217.150.35.129" "185.51.61.101" "37.193.226.251" "46.73.33.253" "80.82.55.71" "212.46.255.78" "62.176.12.111" "193.242.151.45" "77.233.5.68" "195.191.182.103" "80.245.115.97" "46.229.136.244" "84.53.247.204" "46.28.130.214" "91.223.120.25" "81.211.101.154" "46.254.217.54" "62.76.161.12" "62.213.14.166" "94.140.208.226" "86.62.120.68" "195.209.131.19" "85.172.19.214" "185.175.119.206" "109.195.194.79" "91.144.139.3" "185.123.194.28" "95.143.220.5" "79.142.95.90" "31.15.89.51" "46.146.209.132"
# Iran
"185.231.182.126" "46.224.1.42" "185.187.84.15" "37.156.145.229" "185.97.117.187" "185.113.59.253" "80.191.40.41" "2.189.44.44" "2.188.21.131" "2.188.21.132" "81.91.144.116" "2.188.21.130" "92.119.56.162"
# Belarus
"213.184.224.254" "178.124.158.2" "178.124.152.74" "93.125.113.35" "46.175.171.234" "185.183.120.21" "93.84.101.216" "178.124.159.30" "86.57.182.174" "91.149.187.184" "212.98.162.203" "178.124.177.210" "86.57.139.244" "86.57.176.116" "194.158.209.165" "128.65.52.254" "195.222.86.106" "93.84.111.88" "178.124.160.248" "185.152.136.106" "195.50.2.26" "86.57.155.140" "46.216.167.108" "86.57.198.85" "194.158.219.140" "46.216.167.100" "178.124.204.179" "86.57.159.5" "93.125.21.75" "128.65.50.195" "37.17.61.236" "91.149.191.93" "86.57.235.57" "82.209.196.43" "82.209.223.188" "93.125.100.210" "82.209.232.162" "82.209.222.156" "86.57.135.118" "87.252.252.247" "87.252.224.22" "86.57.165.148" "86.57.209.91" "185.183.123.14" "93.84.120.167" "178.124.217.181" "178.124.162.168" "86.57.199.207" "86.57.245.133" "86.57.131.58"
# Syria
"91.144.22.198" "82.137.245.41" "82.137.250.45" "95.159.63.33" "178.253.103.88"
# Venezuela
"138.122.5.218" "186.167.33.244" "186.24.50.164" "190.120.250.165" "190.120.250.221" "45.230.168.17" "190.216.229.111" "190.216.229.245" "190.216.230.18" "190.216.237.1" "190.216.237.18" "190.216.238.105" "190.216.250.222" "190.216.250.42" "190.216.254.200" "190.217.13.229" "190.217.14.105" "190.217.14.213" "190.217.14.25" "190.217.14.45" "190.217.14.65" "190.217.4.78" "190.217.5.132" "190.217.5.161" "190.217.6.145" "190.217.8.247" "190.217.8.254" "200.41.114.91" "201.234.235.90" "204.199.248.34" "45.185.17.33" "200.35.86.182" "190.200.178.197" "186.166.142.196" "190.77.28.245" "190.77.7.86" "190.74.108.6" "201.242.191.158" "200.11.138.11" "201.249.153.60" "186.24.14.114" "190.78.57.226" "190.75.35.240" "45.187.94.147" "45.186.201.40" "190.75.143.216" "190.73.28.245" "190.203.165.255" "201.248.203.64" "200.35.77.10"
# Cuba
"181.225.255.203" "152.206.80.254" "152.206.201.49" "190.15.159.183" "152.206.201.77" "152.206.201.169" "152.206.139.42" "190.15.158.251"
# Pakistan
"182.176.149.66" "125.209.66.170" "59.103.243.83" "59.103.138.123" "180.178.189.118" "110.38.74.58" "110.38.57.243" "118.103.236.13" "221.120.192.202" "110.36.213.38" "58.27.244.146" "180.178.189.68" "210.56.8.8" "103.168.40.14" "223.29.230.190" "103.189.127.102" "125.209.74.126" "203.135.5.90" "103.152.117.145" "103.166.102.21" "203.175.76.129" "202.142.189.98" "202.163.76.123" "43.246.225.217" "103.151.46.13" "121.52.157.202" "61.5.134.35" "58.27.249.124" "221.120.237.70" "103.152.100.142" "103.153.15.79" "115.186.46.233" "202.69.60.254" "202.83.175.188" "103.62.235.10" "103.154.64.142" "116.213.34.101" "137.59.192.182" "203.223.169.178" "111.68.108.215" "202.163.76.75" "103.189.127.107" "202.166.160.75" "123.108.93.129" "103.138.51.141" "103.83.89.154"
# Cambodia
"45.250.237.142" "58.97.212.160" "45.133.168.112" "116.212.151.101" "43.230.195.197" "116.212.140.211" "96.9.88.2" "202.7.52.100" "124.248.191.83" "202.8.73.210" "111.118.147.236" "116.212.143.233" "43.230.192.98" "116.212.139.221" "202.178.113.40" "43.230.195.99" "202.62.58.27" "36.37.181.118" "202.62.58.23" "103.242.58.167" "103.242.58.166" "103.16.63.166" "103.248.42.72" "27.109.116.28" "36.37.230.149" "49.156.42.210" "175.100.18.45" "96.9.69.164" "36.37.160.242"
# Myanmar
"103.129.77.238" "202.191.109.18" "136.228.168.10" "180.235.117.54" "185.205.140.22" "185.133.214.154" "202.191.103.142" "37.111.52.18" "202.165.94.42" "203.81.66.105" "121.54.164.26" "202.165.94.82" "202.165.95.74" "103.85.107.99" "103.116.12.199" "203.81.95.70" "65.18.112.106" "103.80.36.185" "103.85.104.41" "121.54.164.130" "103.25.79.178" "103.115.23.44" "103.213.30.95" "103.80.38.1" "210.14.104.230" "103.121.228.5" "74.50.211.90" "65.18.114.254" "136.228.160.250" "103.154.241.252" "103.121.228.1" "103.85.107.101" "103.203.133.66"
# Nicaragua
"190.106.16.154" "190.106.9.154" "190.106.16.58" "190.124.39.34" "186.1.5.66" "186.1.38.84" "186.1.44.141" "186.1.16.180" "186.1.35.243" "186.1.32.106" "186.1.45.124" "190.212.182.165" "186.1.41.92" "186.1.43.98" "209.124.106.178" "186.1.47.215" "191.98.231.158" "186.1.3.120" "161.0.61.117" "200.62.105.186" "45.170.225.42" "190.106.16.210" "190.106.12.226" "186.1.35.130" "191.102.49.167" "186.1.5.133" "186.1.29.134" "190.106.27.204" "165.98.68.126" "190.212.138.62" "186.1.41.26" "200.62.96.39" "161.0.62.217" "190.106.2.103" "209.124.106.181" "209.124.101.114"
# Eritrea - No public DNS servers
# Mali
"217.64.99.25" "196.200.48.40" "154.118.190.94"
# Central African Republic - No public DNS servers
# Burkina Faso
"196.28.245.26" "154.65.61.1" "41.216.154.11" "102.222.123.60" "196.28.244.3" "165.16.213.111" "41.138.101.251" "41.216.159.6" "206.82.130.195" "102.222.56.2" "41.216.155.193" "102.36.165.254"
# Niger
"102.215.85.114" "102.215.85.106" "102.215.86.142"
# Greenland
"194.177.224.47"
)

# Domain URLs for entities
declare -A domain_urls
domain_urls[ve]="https://raw.githubusercontent.com/blocklistproject/Lists/master/scam.txt"
domain_urls[ru]="https://raw.githubusercontent.com/blocklistproject/Lists/master/phishing.txt"
domain_urls[cn]="https://raw.githubusercontent.com/carrnot/china-domain-list/release/domain.txt"
domain_urls[go]="https://raw.githubusercontent.com/nickspaargaren/no-google/master/pihole-google.txt"
domain_urls[ms]="https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
domain_urls[am]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/native.amazon.txt"
domain_urls[me]="https://raw.githubusercontent.com/nickspaargaren/no-facebook/master/pihole-facebook.txt"
domain_urls[ap]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/native.apple.txt"
domain_urls[nf]="https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/native.netflix.txt"
default_domain_url="https://raw.githubusercontent.com/blocklistproject/Lists/master/phishing.txt"

# Domain processing
declare -A domain_process
domain_process[ve]="grep -v '^#'"
domain_process[ru]="grep -v '^#'"
domain_process[cn]="grep -v '^#' | sed 's/^/0.0.0.0 /'"
domain_process[go]="grep -v '^#' | sed 's/^/0.0.0.0 /'"
domain_process[ms]="grep -v '^#' | awk '{print \$2}' | sed 's/^/0.0.0.0 /'"
domain_process[am]="grep -v '^#' | sed 's/^/0.0.0.0 /'"
domain_process[me]="grep -v '^#' | sed 's/^/0.0.0.0 /'"
domain_process[ap]="grep -v '^#' | sed 's/^/0.0.0.0 /'"
domain_process[nf]="grep -v '^#' | sed 's/^/0.0.0.0 /'"
default_domain_process="grep -v '^#' | sed 's/^/0.0.0.0 /'"

# IP URLs
declare -A ip_urls
for code in "${entities[@]}"; do
  if [[ $code =~ ^[a-z]{2}$ ]]; then
    ip_urls[$code]="https://www.ipdeny.com/ipblocks/data/aggregated/${code}-aggregated.zone"
  fi
done
ip_urls[go]="https://www.gstatic.com/ipranges/goog.json"
ip_urls[ms]="https://download.microsoft.com/download/7/1/D/71D86715-5596-4529-9B13-DA13A5DE5B63/ServiceTags_Public_20240108.json"
ip_urls[am]="https://ip-ranges.amazonaws.com/ip-ranges.json"
ip_urls[me]="https://www.gstatic.com/ipranges/goog.json" # Placeholder
ip_urls[ap]="https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer" # Placeholder, no IP list
ip_urls[nf]="https://ip-ranges.amazonaws.com/ip-ranges.json"

# IP parse
declare -A ip_parse
ip_parse[go]="jq -r '.prefixes[].ipv4Prefix // empty'"
ip_parse[ms]="jq -r '.values[].properties.addressPrefixes[] | select(contains(\":\")|not)'"
ip_parse[am]="jq -r '.prefixes[].ip_prefix'"
ip_parse[nf]="jq -r '.prefixes[].ip_prefix'"
default_ip_parse="cat"

# Packages
declare -A packages
packages[go]="google* chromium* widevine*"
packages[ms]="microsoft* azure* edge* teams skype* code"
packages[am]="amazon* aws*"
packages[me]="meta* facebook* instagram*"
packages[ap]="apple*"
packages[nf]="netflix*"

# TLDs
declare -A tlds
tlds[ru]=".ru .su"
tlds[cn]=".cn .com.cn .org.cn"
tlds[ir]=".ir"
tlds[kp]=".kp"
tlds[by]=".by"
tlds[sy]=".sy"
tlds[ve]=".ve"
tlds[cu]=".cu"
tlds[pk]=".pk"
tlds[kh]=".kh"
tlds[mm]=".mm"
tlds[ni]=".ni"
tlds[er]=".er"
tlds[ml]=".ml"
tlds[cf]=".cf"
tlds[bf]=".bf"
tlds[ne]=".ne"
tlds[gl]=".gl"

# Backup
function backup_configs() {
  cp $HOSTS_FILE $HOSTS_BACKUP
  nft list ruleset > $NFT_BACKUP
}

# Restore
function restore_configs() {
  cp $HOSTS_BACKUP $HOSTS_FILE
  nft -f $NFT_BACKUP
  rm -f $DNSMASQ_CONF
  systemctl restart dnsmasq
}

# Flush
function flush_rules() {
  nft flush table ip anticrack || nft add table ip anticrack
  nft add chain ip anticrack input { type filter hook input priority -10 \; policy drop \; }
  nft add chain ip anticrack output { type filter hook output priority -10 \; policy drop \; }
  cp $HOSTS_BACKUP $HOSTS_FILE
  > $DNSMASQ_CONF
  systemctl restart dnsmasq
}

# Block DNS IPs
function block_dns_ips() {
  for ip in "${dns_ips[@]}"; do
    nft add rule ip anticrack input ip saddr $ip drop
    nft add rule ip anticrack output ip daddr $ip drop
  done
}

# Block TOR bridges (via Directory Authorities)
function block_tor_bridges() {
  for ip in "${tor_da_ips[@]}"; do
    nft add rule ip anticrack input ip saddr $ip drop
    nft add rule ip anticrack output ip daddr $ip drop
  done
  echo "TOR bridges blocked via Directory Authorities."
}

# Setup CrowdSec
function setup_crowdsec() {
  systemctl enable --now crowdsec
  cscli collections install crowdsecurity/linux
  cscli parsers install crowdsecurity/whitelists
  systemctl reload crowdsec
  systemctl enable --now crowdsec-firewall-bouncer
  echo "CrowdSec integrated with nftables."
}

# Block entity
function block_entity() {
  local code=$1
  local name=${entity_names[$code]:-"Unknown"}

  echo "$(date) Blocking $name" >> $LOG_FILE

  # Domains
  local d_url=${domain_urls[$code]:-$default_domain_url}
  local d_proc=${domain_process[$code]:-$default_domain_process}
  curl -s $d_url | eval $d_proc >> /tmp/domains.txt
  echo "# anticrack-start $code" >> $HOSTS_FILE
  cat /tmp/domains.txt >> $HOSTS_FILE
  echo "# anticrack-end $code" >> $HOSTS_FILE

  # IPs
  local i_url=${ip_urls[$code]}
  local i_proc=${ip_parse[$code]:-$default_ip_parse}
  if [[ -n $i_url ]]; then
    curl -s $i_url | eval $i_proc > /tmp/ips.txt
  elif [[ $code == "nsa" ]]; then
    printf "%s\n" "${nsa_ips[@]}" > /tmp/ips.txt
  elif [[ $code == "fbi" ]]; then
    printf "%s\n" "${fbi_ips[@]}" > /tmp/ips.txt
  elif [[ $code == "gchq" ]]; then
    printf "%s\n" "${gchq_ips[@]}" > /tmp/ips.txt
  elif [[ $code == "mi6" ]]; then
    printf "%s\n" "${mi6_ips[@]}" > /tmp/ips.txt
  fi
  if [ -s /tmp/ips.txt ]; then
    while read -r ip; do
      nft add rule ip anticrack input ip saddr $ip log prefix \"Anticrack drop: \" drop
      nft add rule ip anticrack output ip daddr $ip log prefix \"Anticrack drop: \" drop
    done < /tmp/ips.txt
  fi

  # Packages
  local pkgs=${packages[$code]:-"${code}*"}
  apt purge -y $pkgs 2>/dev/null

  # TLDs
  if [[ -n ${tlds[$code]} ]]; then
    for tld in ${tlds[$code]}; do
      echo "address=/$tld/0.0.0.0" >> $DNSMASQ_CONF
    done
  fi

  echo "$name blocked."
}

# Disable entity
function disable_entity() {
  local code=$1
  sed -i "/# anticrack-start $code/,/# anticrack-end $code/d" $HOSTS_FILE
  sed -i "/$code/d" $DNSMASQ_CONF
  echo "$(date) Unblocking ${entity_names[$code]}" >> $LOG_FILE
  echo "${entity_names[$code]} unblocked."
}

# Apply all
function apply_all() {
  flush_rules
  block_dns_ips
  if [ -f $WHITELIST_FILE ]; then
    while read -r wl; do
      nft add rule ip anticrack input ip saddr $wl accept
      nft add rule ip anticrack output ip daddr $wl accept
    done < $WHITELIST_FILE
  fi
  if [ -f $BLOCKED_FILE ]; then
    while read -r code; do
      block_entity $code
    done < $BLOCKED_FILE
  fi
  systemctl restart dnsmasq
  netfilter-persistent save
}

# Block group
function block_group() {
  local group=$1
  for code in ${groups[$group]}; do
    if ! grep -q "^$code$" $BLOCKED_FILE; then
      echo $code >> $BLOCKED_FILE
    fi
  done
  apply_all
}

# Disable group
function disable_group() {
  local group=$1
  for code in ${groups[$group]}; do
    disable_entity $code
    sed -i "/^$code$/d" $BLOCKED_FILE
  done
  apply_all
}

# Status
function show_status() {
  echo "Blocked entities:"
  cat $BLOCKED_FILE 2>/dev/null || echo "None"
  echo "Whitelist:"
  cat $WHITELIST_FILE 2>/dev/null || echo "None"
  nft list ruleset
  tail -n 20 $LOG_FILE
}

# Total lockdown
function total_lockdown() {
  block_group "all"
  # Block TOR exits
  curl -s https://www.dan.me.uk/torlist/ > /tmp/tor.txt
  while read -r ip; do
    nft add rule ip anticrack input ip saddr $ip drop
    nft add rule ip anticrack output ip daddr $ip drop
  done < /tmp/tor.txt
  # Block TOR bridges via DA
  block_tor_bridges
  # Setup CrowdSec
  setup_crowdsec
  # Fail2Ban, Suricata, Snort
  systemctl restart fail2ban suricata snort
  suricata-update
  # Rate limiting SSH
  nft add rule ip anticrack input tcp dport 22 limit rate 3/minute burst 5 packets accept
  nft add rule ip anticrack input tcp dport 22 drop
  # Log all drops
  nft add rule ip anticrack input log prefix \"Anticrack input drop: \" drop
  nft add rule ip anticrack output log prefix \"Anticrack output drop: \" drop
  echo "Total lockdown enabled with bridge blocking and CrowdSec."
}

# Update lists
function update_lists() {
  apply_all
  echo "Lists updated."
}

# Add whitelist
function add_whitelist() {
  local item=$1
  echo $item >> $WHITELIST_FILE
  apply_all
  echo "$item whitelisted."
}

# Setup cron
function setup_cron() {
  (crontab -l 2>/dev/null; echo "@daily $0 update") | crontab -
  echo "Cron setup for daily updates."
}

# Menu
function menu() {
  while true; do
    echo "Anticrack Gamma v1.0 - Ultimate Form"
    echo "1) Block an entity"
    echo "2) Block a group"
    echo "3) Disable an entity"
    echo "4) Disable a group"
    echo "5) Show status"
    echo "6) Total lockdown"
    echo "7) Update lists"
    echo "8) Add whitelist (IP/domain)"
    echo "9) Setup cron updates"
    echo "10) Exit"
    read -p "Choose option: " opt
    case $opt in
      1) read -p "Enter code: " code
         if [[ " ${entities[*]} " =~ " ${code} " ]]; then
           echo $code >> $BLOCKED_FILE
           apply_all
         else
           echo "Invalid code."
         fi ;;
      2) echo "Groups: ${!groups[@]}"
         read -p "Enter group: " group
         if [[ -n ${groups[$group]} ]]; then
           block_group $group
         else
           echo "Invalid group."
         fi ;;
      3) read -p "Enter code: " code
         disable_entity $code
         sed -i "/^$code$/d" $BLOCKED_FILE
         apply_all ;;
      4) echo "Groups: ${!groups[@]}"
         read -p "Enter group: " group
         disable_group $group ;;
      5) show_status ;;
      6) total_lockdown ;;
      7) update_lists ;;
      8) read -p "Enter IP/domain: " item
         add_whitelist $item ;;
      9) setup_cron ;;
      10) exit 0 ;;
      *) echo "Invalid option." ;;
    esac
  done
}

# Set DNS
echo "nameserver 9.9.9.9" > /etc/resolv.conf

# Initial backup
if [ ! -f $HOSTS_BACKUP ]; then
  backup_configs
fi

# Run menu
menu

# License: GPL-3.0
