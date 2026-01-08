#!/bin/bash

if [ "$(id -u)" != "0" ]; then
   echo "Run as root." 1>&2
   exit 1
fi

command -v ipset >/dev/null 2>&1 || apt install -y ipset
command -v wget >/dev/null 2>&1 || apt install -y wget

declare -A country_names
country_names=( [cn]="China" [ru]="Russia" [ir]="Iran" [kp]="North Korea" [by]="Belarus" [sy]="Syria" [ve]="Venezuela" [cu]="Cuba" [pk]="Pakistan" [kh]="Cambodia" [mm]="Myanmar" [ni]="Nicaragua" [er]="Eritrea" [ml]="Mali" [cf]="Central African Republic" [bf]="Burkina Faso" [ne]="Niger" [gl]="Greenland"
[al]="Albania" [be]="Belgium" [bg]="Bulgaria" [ca]="Canada" [hr]="Croatia" [cz]="Czech Republic" [dk]="Denmark" [ee]="Estonia" [fi]="Finland" [fr]="France" [de]="Germany" [gr]="Greece" [hu]="Hungary" [is]="Iceland" [it]="Italy" [lv]="Latvia" [lt]="Lithuania" [lu]="Luxembourg" [me]="Montenegro" [nl]="Netherlands" [mk]="North Macedonia" [no]="Norway" [pl]="Poland" [pt]="Portugal" [ro]="Romania" [sk]="Slovakia" [si]="Slovenia" [es]="Spain" [se]="Sweden" [tr]="Turkey" [gb]="United Kingdom" [us]="United States" )

countries=(cn ru ir kp by sy ve cu pk kh mm ni er ml cf bf ne gl al be bg ca hr cz dk ee fi fr de gr hu is it lv lt lu me nl mk no pl pt ro sk si es se tr gb us)

declare -A groups
groups[enemies]="cn ru ir kp"
groups[allies]="by sy ve cu pk kh mm ni er ml cf bf ne"
groups[all_enemies]="cn ru ir kp by sy ve cu pk kh mm ni er ml cf bf ne"
groups[nato]="al be bg ca hr cz dk ee fi fr de gr hu is it lv lt lu me nl mk no pl pt ro sk si es se tr gb us"
groups[greenland]="gl"

dns_ips=("202.46.34.74" "202.46.34.76" "114.114.115.119" "114.114.114.114" "114.114.115.115" "202.46.33.250" "103.251.105.188" "1.12.13.53" "121.4.4.41" "103.144.53.209" "223.6.6.199" "223.5.5.17" "103.144.53.104" "120.53.53.84" "223.6.6.198" "223.5.5.219" "140.210.69.173" "223.6.6.141" "223.6.6.56" "103.251.106.105" "103.144.52.233" "223.6.6.72" "120.53.53.116" "223.5.5.51" "223.6.6.46" "223.5.5.190" "120.53.53.183" "223.6.6.169" "223.6.6.195" "103.144.52.214" "223.5.5.224" "173.82.141.168" "223.5.5.111" "223.6.6.6" "120.53.53.54" "223.6.6.17" "120.53.53.198" "202.46.34.75" "103.144.52.240" "223.6.6.204" "223.5.5.228" "223.6.6.127" "223.5.5.148" "223.6.6.133" "121.4.4.246" "223.5.5.187" "223.5.5.123" "223.5.5.82" "223.6.6.139" "223.5.5.79"
"77.88.8.1" "77.88.8.3" "77.88.8.88" "94.158.96.2" "92.223.65.71" "194.67.109.176" "195.112.96.34" "195.208.5.1" "89.250.221.106" "93.157.172.153" "5.44.54.106" "94.180.111.233" "178.161.150.190" "217.150.35.129" "185.51.61.101" "37.193.226.251" "46.73.33.253" "80.82.55.71" "212.46.255.78" "62.176.12.111" "193.242.151.45" "77.233.5.68" "195.191.182.103" "80.245.115.97" "46.229.136.244" "84.53.247.204" "46.28.130.214" "91.223.120.25" "81.211.101.154" "46.254.217.54" "62.76.161.12" "62.213.14.166" "94.140.208.226" "86.62.120.68" "195.209.131.19" "85.172.19.214" "185.175.119.206" "109.195.194.79" "91.144.139.3" "185.123.194.28" "95.143.220.5" "79.142.95.90" "31.15.89.51" "46.146.209.132"
"185.231.182.126" "46.224.1.42" "185.187.84.15" "37.156.145.229" "185.97.117.187" "185.113.59.253" "80.191.40.41" "2.189.44.44" "2.188.21.131" "2.188.21.132" "81.91.144.116" "2.188.21.130" "92.119.56.162"
"213.184.224.254" "178.124.158.2" "178.124.152.74" "93.125.113.35" "46.175.171.234" "185.183.120.21" "93.84.101.216" "178.124.159.30" "86.57.182.174" "91.149.187.184" "212.98.162.203" "178.124.177.210" "86.57.139.244" "86.57.176.116" "194.158.209.165" "128.65.52.254" "195.222.86.106" "93.84.111.88" "178.124.160.248" "185.152.136.106" "195.50.2.26" "86.57.155.140" "46.216.167.108" "86.57.198.85" "194.158.219.140" "46.216.167.100" "178.124.204.179" "86.57.159.5" "93.125.21.75" "128.65.50.195" "37.17.61.236" "91.149.191.93" "86.57.235.57" "82.209.196.43" "82.209.223.188" "93.125.100.210" "82.209.232.162" "82.209.222.156" "86.57.135.118" "87.252.252.247" "87.252.224.22" "86.57.165.148" "86.57.209.91" "185.183.123.14" "93.84.120.167" "178.124.217.181" "178.124.162.168" "86.57.199.207" "86.57.245.133" "86.57.131.58"
"91.144.22.198" "82.137.245.41" "82.137.250.45" "95.159.63.33" "178.253.103.88"
"138.122.5.218" "186.167.33.244" "186.24.50.164" "190.120.250.165" "190.120.250.221" "45.230.168.17" "190.216.229.111" "190.216.229.245" "190.216.230.18" "190.216.237.1" "190.216.237.18" "190.216.238.105" "190.216.250.222" "190.216.250.42" "190.216.254.200" "190.217.13.229" "190.217.14.105" "190.217.14.213" "190.217.14.25" "190.217.14.45" "190.217.14.65" "190.217.4.78" "190.217.5.132" "190.217.5.161" "190.217.6.145" "190.217.8.247" "190.217.8.254" "200.41.114.91" "201.234.235.90" "204.199.248.34" "45.185.17.33" "200.35.86.182" "190.200.178.197" "186.166.142.196" "190.77.28.245" "190.77.7.86" "190.74.108.6" "201.242.191.158" "200.11.138.11" "201.249.153.60" "186.24.14.114" "190.78.57.226" "190.75.35.240" "45.187.94.147" "45.186.201.40" "190.75.143.216" "190.73.28.245" "190.203.165.255" "201.248.203.64" "200.35.77.10"
"181.225.255.203" "152.206.80.254" "152.206.201.49" "190.15.159.183" "152.206.201.77" "152.206.201.169" "152.206.139.42" "190.15.158.251"
"182.176.149.66" "125.209.66.170" "59.103.243.83" "59.103.138.123" "180.178.189.118" "110.38.74.58" "110.38.57.243" "118.103.236.13" "221.120.192.202" "110.36.213.38" "58.27.244.146" "180.178.189.68" "210.56.8.8" "103.168.40.14" "223.29.230.190" "103.189.127.102" "125.209.74.126" "203.135.5.90" "103.152.117.145" "103.166.102.21" "203.175.76.129" "202.142.189.98" "202.163.76.123" "43.246.225.217" "103.151.46.13" "121.52.157.202" "61.5.134.35" "58.27.249.124" "221.120.237.70" "103.152.100.142" "103.153.15.79" "115.186.46.233" "202.69.60.254" "202.83.175.188" "103.62.235.10" "103.154.64.142" "116.213.34.101" "137.59.192.182" "203.223.169.178" "111.68.108.215" "202.163.76.75" "103.189.127.107" "202.166.160.75" "123.108.93.129" "103.138.51.141" "103.83.89.154" "202.63.198.49" "119.156.31.221" "103.189.127.109" "103.115.199.129"
"36.37.160.242" "96.9.69.164" "175.100.18.45" "49.156.42.210" "36.37.230.149" "27.109.116.28" "103.248.42.72" "103.16.63.166" "103.242.58.166" "103.242.58.167" "202.62.58.23" "36.37.181.118" "202.62.58.27" "43.230.192.98" "43.230.195.99" "202.178.113.40" "116.212.140.211" "116.212.139.221" "96.9.88.2" "116.212.143.233" "111.118.147.236" "202.8.73.210" "124.248.191.83" "202.7.52.100" "43.230.195.197" "116.212.151.101" "45.133.168.112" "202.62.59.234" "103.16.61.114" "45.250.237.142" "203.189.130.131" "96.9.88.185"
"103.116.12.199" "103.203.133.66" "103.85.107.99" "103.85.107.101" "103.121.228.1" "103.154.241.252" "136.228.160.250" "65.18.114.254" "74.50.211.90" "210.14.104.230" "203.81.95.70" "103.121.228.5" "103.80.38.1" "103.213.30.95" "103.115.23.44" "103.25.79.178" "103.85.104.41" "121.54.164.130" "103.80.36.185" "65.18.112.106" "121.54.164.26" "202.165.95.74" "202.165.94.82" "203.81.66.105" "185.133.214.154" "185.205.140.22" "202.165.94.42" "37.111.52.18" "202.191.103.142" "180.235.117.54" "136.228.168.10" "202.191.109.18" "103.129.77.238"
"209.124.101.114" "209.124.106.181" "190.106.2.103" "161.0.62.217" "200.62.96.39" "186.1.41.26" "190.212.138.62" "165.98.68.126" "186.1.29.134" "190.106.27.204" "186.1.5.133" "191.102.49.167" "186.1.35.130" "190.106.12.226" "186.1.3.120" "191.98.231.158" "186.1.47.215" "209.124.106.178" "190.106.16.210" "45.170.225.42" "200.62.105.186" "161.0.61.117" "186.1.43.98" "186.1.41.92" "190.212.182.165" "186.1.45.124" "186.1.32.106" "186.1.35.243" "186.1.16.180" "186.1.44.141" "186.1.38.84" "186.1.5.66" "190.124.39.34" "190.106.16.58" "190.106.9.154" "190.106.26.158" "191.98.230.2" "161.0.36.214" "190.106.13.102" "191.98.238.202" "191.98.236.242" "186.1.14.164"
"154.118.190.94" "196.200.48.40" "217.64.99.25"
"206.82.130.195" "102.36.165.254" "41.216.155.193" "102.222.56.2" "41.216.159.6" "41.138.101.251" "165.16.213.111" "196.28.244.3" "102.222.123.60" "41.216.154.11" "160.226.184.252" "41.216.155.245")

tech_domains=("google.com" "youtube.com" "facebook.com" "instagram.com" "amazon.com" "microsoft.com" "apple.com" "netflix.com" "x.com" "tiktok.com" "whatsapp.com" "linkedin.com" "yahoo.com" "baidu.com" "yandex.ru" "alibaba.com")

enemy_social_domains=("vk.com" "ok.ru" "rutube.ru" "mail.ru" "weibo.com" "qq.com" "weixin.qq.com" "douyin.com" "bilibili.com" "aparat.ir" "cloob.com" "bale.ai" "soroush-app.ir")

HOSTS_FILE="/etc/hosts"
BLOCK_MARKER="# AntiCrack Domain Block"
BLOCKED_DOMAINS_FILE="/tmp/anticrack_domains.txt"

function status_country() {
  local c=$1
  if ipset list "block-$c" >/dev/null 2>&1; then
    echo "Enabled"
  else
    echo "Disabled"
  fi
}

function enable_country() {
  local c=$1
  if [ "$(status_country $c)" == "Enabled" ]; then
    echo "${country_names[$c]} already enabled."
    return
  fi
  wget -q "https://www.ipdeny.com/ipblocks/data/aggregated/${c}-aggregated.zone" -O "/tmp/${c}.zone"
  ipset create "block-$c" hash:net
  while read -r ip; do
    ipset add "block-$c" "$ip"
  done < "/tmp/${c}.zone"
  rm "/tmp/${c}.zone"
  iptables -A INPUT -m set --match-set "block-$c" src -j DROP
  iptables -A OUTPUT -m set --match-set "block-$c" dst -j DROP
  echo "${country_names[$c]} enabled."
}

function disable_country() {
  local c=$1
  if [ "$(status_country $c)" == "Disabled" ]; then
    echo "${country_names[$c]} already disabled."
    return
  fi
  iptables -D INPUT -m set --match-set "block-$c" src -j DROP 2>/dev/null
  iptables -D OUTPUT -m set --match-set "block-$c" dst -j DROP 2>/dev/null
  ipset destroy "block-$c" 2>/dev/null
  echo "${country_names[$c]} disabled."
}

function enable_group() {
  local g=$1
  for c in ${groups[$g]}; do
    enable_country $c
  done
  echo "$g group enabled."
}

function disable_group() {
  local g=$1
  for c in ${groups[$g]}; do
    disable_country $c
  done
  echo "$g group disabled."
}

function create_custom_group() {
  read -p "Custom group name: " group
  if [[ -n "${groups[$group]}" ]]; then
    echo "Group exists."
    return
  fi
  echo "Enter countries in format 'Country: code, Country: code' (e.g., Russia: ru, China: cn)"
  read -p "Countries: " input
  codes=$(echo "$input" | sed 's/[^:]*: \([a-z][a-z]\),*/\1 /g')
  groups[$group]="$codes"
  echo "Custom group $group created with codes: $codes"
}

function status_dns() {
  if ipset list block-dns >/dev/null 2>&1; then
    echo "Enabled"
  else
    echo "Disabled"
  fi
}

function enable_dns_block() {
  if [ "$(status_dns)" == "Enabled" ]; then
    echo "DNS block already enabled."
    return
  fi
  ipset create block-dns hash:ip
  for ip in "${dns_ips[@]}"; do
    ipset add block-dns "$ip" 2>/dev/null
  done
  iptables -A INPUT -m set --match-set block-dns src -j DROP
  iptables -A OUTPUT -m set --match-set block-dns dst -j DROP
  echo "Enemy DNS blocked."
}

function disable_dns_block() {
  if [ "$(status_dns)" == "Disabled" ]; then
    echo "DNS block already disabled."
    return
  fi
  iptables -D INPUT -m set --match-set block-dns src -j DROP 2>/dev/null
  iptables -D OUTPUT -m set --match-set block-dns dst -j DROP 2>/dev/null
  ipset destroy block-dns 2>/dev/null
  echo "Enemy DNS unblocked."
}

function enable_tech_block() {
  for d in "${tech_domains[@]}"; do
    block_domain "$d"
  done
  echo "Tech companies blocked."
}

function disable_tech_block() {
  for d in "${tech_domains[@]}"; do
    unblock_domain "$d"
  done
  echo "Tech companies unblocked."
}

function status_tech() {
  local blocked=0
  local total=${#tech_domains[@]}
  for d in "${tech_domains[@]}"; do
    if [ "$(status_domain $d)" == "Blocked" ]; then
      ((blocked++))
    fi
  done
  if [ $blocked -eq $total ]; then
    echo "Enabled"
  elif [ $blocked -eq 0 ]; then
    echo "Disabled"
  else
    echo "Partial ($blocked/$total)"
  fi
}

function enable_enemy_social_block() {
  for d in "${enemy_social_domains[@]}"; do
    block_domain "$d"
  done
  echo "Enemy social media blocked."
}

function disable_enemy_social_block() {
  for d in "${enemy_social_domains[@]}"; do
    unblock_domain "$d"
  done
  echo "Enemy social media unblocked."
}

function status_enemy_social() {
  local blocked=0
  local total=${#enemy_social_domains[@]}
  for d in "${enemy_social_domains[@]}"; do
    if [ "$(status_domain $d)" == "Blocked" ]; then
      ((blocked++))
    fi
  done
  if [ $blocked -eq $total ]; then
    echo "Enabled"
  elif [ $blocked -eq 0 ]; then
    echo "Disabled"
  else
    echo "Partial ($blocked/$total)"
  fi
}

function total_lockdown() {
  enable_group all_enemies
  enable_dns_block
  enable_tech_block
  enable_enemy_social_block
  echo "Total lockdown enabled - all enemy IPs, DNS, tech, and social media blocked."
}

function list_status() {
  echo "Countries:"
  for c in "${countries[@]}"; do
    echo "${country_names[$c]} ($c): $(status_country $c) - Blocks IP traffic to/from country."
  done
  echo "Enemy DNS: $(status_dns) - Blocks enemy DNS servers."
  echo "Tech Companies: $(status_tech) - Blocks major tech domains."
  echo "Enemy Social Media: $(status_enemy_social) - Blocks enemy social platforms."
}

function status_domain() {
  local d=$1
  if grep -q "^0.0.0.0 $d $BLOCK_MARKER" "$HOSTS_FILE"; then
    echo "Blocked"
  else
    echo "Not blocked"
  fi
}

function block_domain() {
  local d=$1
  if [ "$(status_domain $d)" == "Blocked" ]; then
    echo "$d already blocked."
    return
  fi
  echo "0.0.0.0 $d $BLOCK_MARKER" >> "$HOSTS_FILE"
  echo "$d blocked."
}

function unblock_domain() {
  local d=$1
  if [ "$(status_domain $d)" == "Not blocked" ]; then
    echo "$d not blocked."
    return
  fi
  sed -i "/^0.0.0.0 $d $BLOCK_MARKER/d" "$HOSTS_FILE"
  echo "$d unblocked."
}

function list_blocked_domains() {
  grep "$BLOCK_MARKER" "$HOSTS_FILE" | awk '{print $2 " - Blocked domain."}' > "$BLOCKED_DOMAINS_FILE"
  if [ -s "$BLOCKED_DOMAINS_FILE" ]; then
    cat "$BLOCKED_DOMAINS_FILE"
  else
    echo "No domains blocked."
  fi
  rm -f "$BLOCKED_DOMAINS_FILE"
}

function list_countries() {
  for c in "${!country_names[@]}"; do
    echo "${country_names[$c]}: $c"
  done
}

echo "AntiCrack Global Blocker"
echo "Secures US internet by blocking enemies in WW3. Blocks IPs, domains, DNS for total network/web lockdown."
echo "Warning: Root required. May break access. Backup configs. Use at own risk."
echo "Available countries for custom groups:"
list_countries
echo "Improved with expanded enemy DNS, social media blocks, NATO option, custom groups."

while true; do
  echo "1) List status - Shows status of all blocks."
  echo "2) Enable country - Enter code to block IP ranges."
  echo "3) Disable country - Enter code to unblock."
  echo "4) Status of country - Enter code to check."
  echo "5) Enable group (enemies/allies/all_enemies/nato/greenland/custom) - Blocks group IPs."
  echo "6) Disable group - Unblocks group."
  echo "7) List blocked domains - Shows blocked domains."
  echo "8) Block domain - Enter domain to block via hosts."
  echo "9) Unblock domain - Enter domain to unblock."
  echo "10) Status of domain - Enter domain to check."
  echo "11) Enable DNS block - Blocks all enemy DNS IPs."
  echo "12) Disable DNS block - Unblocks."
  echo "13) Status of DNS block - Checks status."
  echo "14) Enable tech block - Blocks major tech domains."
  echo "15) Disable tech block - Unblocks."
  echo "16) Status of tech block - Checks."
  echo "17) Enable enemy social block - Blocks Russian/enemy social media."
  echo "18) Disable enemy social block - Unblocks."
  echo "19) Status of enemy social block - Checks."
  echo "20) Create custom group - Name group, enter 'Country: code, ...' to create."
  echo "21) Total lockdown - Enables all enemy blocks."
  echo "22) Exit"
  read -p "Choice: " choice
  case $choice in
    1) list_status ;;
    2) read -p "Country code: " code
       if [[ " ${countries[*]} " =~ " ${code} " ]]; then enable_country $code; else echo "Invalid."; fi ;;
    3) read -p "Country code: " code
       if [[ " ${countries[*]} " =~ " ${code} " ]]; then disable_country $code; else echo "Invalid."; fi ;;
    4) read -p "Country code: " code
       if [[ " ${countries[*]} " =~ " ${code} " ]]; then echo "${country_names[$code]}: $(status_country $code)"; else echo "Invalid."; fi ;;
    5) read -p "Group: " group
       if [[ -n "${groups[$group]}" ]]; then enable_group $group; else echo "Invalid."; fi ;;
    6) read -p "Group: " group
       if [[ -n "${groups[$group]}" ]]; then disable_group $group; else echo "Invalid."; fi ;;
    7) list_blocked_domains ;;
    8) read -p "Domain: " domain
       if [[ -n "$domain" ]]; then block_domain $domain; else echo "Invalid."; fi ;;
    9) read -p "Domain: " domain
       if [[ -n "$domain" ]]; then unblock_domain $domain; else echo "Invalid."; fi ;;
    10) read -p "Domain: " domain
       if [[ -n "$domain" ]]; then echo "$domain: $(status_domain $domain)"; else echo "Invalid."; fi ;;
    11) enable_dns_block ;;
    12) disable_dns_block ;;
    13) echo "Enemy DNS: $(status_dns)" ;;
    14) enable_tech_block ;;
    15) disable_tech_block ;;
    16) echo "Tech Companies: $(status_tech)" ;;
    17) enable_enemy_social_block ;;
    18) disable_enemy_social_block ;;
    19) echo "Enemy Social: $(status_enemy_social)" ;;
    20) create_custom_group ;;
    21) total_lockdown ;;
    22) read -p "Save rules? (y/n): " save
       if [ "$save" == "y" ]; then iptables-save > /etc/iptables.rules; echo "Saved."; fi
       exit 0 ;;
    *) echo "Invalid." ;;
  esac
done
