#!/usr/bin/env bash
#
# setup-helper.sh
# - update system
# - set randomized root password and save to /root/.root.pass
# - optionally create user with typed or randomized password saved to /root/.[username].pass
# - optionally change hostname
# - optionally set static IPv4 via netplan (if available)
# - show created password files and optionally su to new user
#
# NOTE: run as root (sudo ./setup-helper.sh)
#

# ---- safety & helpers ----
umask 077
SCRIPT_NAME=$(basename "$0")
LOGPREFIX="[$SCRIPT_NAME]"

echoinfo() { printf "%s %s\n" "$LOGPREFIX" "$*"; }
echoerr() { printf "%s ERROR: %s\n" "$LOGPREFIX" "$*" >&2; }

# run a command but don't exit on failure; capture status and show error
run_step() {
  local step_desc="$1"; shift
  echoinfo "Starting: $step_desc"
  if "$@"; then
    echoinfo "Done: $step_desc"
    return 0
  else
    local s=$?
    echoerr "Step failed ($step_desc) with exit code $s. Skipping to next step."
    return $s
  fi
}

# read with default
read_default() {
  local prompt="$1"
  local default="$2"
  local ans
  if [ -t 0 ]; then
    read -rp "$prompt [$default]: " ans
  else
    # if non-interactive, return default
    ans="$default"
  fi
  if [ -z "$ans" ]; then
    ans="$default"
  fi
  printf "%s" "$ans"
}

# generate random alphanumeric string length N (N must be >0)
rand_alnum() {
  local len=${1:-12}
  # tr may drop bytes, loop until length satisfied
  local out=""
  while [ ${#out} -lt "$len" ]; do
    out="$out$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c $((len - ${#out})))"
  done
  printf "%s" "$out"
}

# ensure running as root
if [ "$(id -u)" -ne 0 ]; then
  echoerr "This script must be run as root. Try: sudo $0"
  exit 2
fi

CREATED_FILES=()

# ---- STEP 0: update system ----
run_step "apt update && apt upgrade -y" bash -c 'apt update -y && apt upgrade -y' || true

# ---- STEP 1: set root password ----
step_root_pass() {
  local LEN
  LEN=$(shuf -i 13-15 -n 1)
  local PASS
  PASS=$(rand_alnum "$LEN")
  local PASSFILE="/root/.root.pass"

  # write password file
  if ! printf "%s\n" "$PASS" >"$PASSFILE"; then
    echoerr "Failed to write root password file to $PASSFILE"
    return 1
  fi
  chmod 600 "$PASSFILE"
  CREATED_FILES+=("$PASSFILE")

  # set password for root
  if ! echo "root:$PASS" | chpasswd; then
    echoerr "Failed to set root password (chpasswd failed)."
    return 1
  fi

  echoinfo "Root password set and saved to $PASSFILE"
  printf "\n==== ROOT PASSWORD ====\n%s\n=======================\n\n" "$PASS"
  return 0
}
run_step "Set randomized root password and save to /root/.root.pass" step_root_pass || true

# ---- STEP 2: create a user and password ----
step_create_user() {
  local create_answer
  create_answer=$(read_default "Do you want to create a new user? (y/n)" "n")
  create_answer=${create_answer,,} # lower
  if [[ "$create_answer" != "y" && "$create_answer" != "yes" ]]; then
    echoinfo "Skipping user creation per user choice."
    return 0
  fi

  # username prompt
  local username
  username=$(read_default "Enter the new username" "")
  if [ -z "$username" ]; then
    echoerr "No username provided; skipping user creation."
    return 1
  fi

  # check if user exists
  if id "$username" &>/dev/null; then
    echoinfo "User '$username' already exists. Will not recreate; will prompt to reset password."
  else
    if ! useradd -m -s /bin/bash "$username"; then
      echoerr "Failed to create user '$username'."
      return 1
    fi
    echoinfo "User '$username' created."
  fi

  # password choice
  local pw_choice
  pw_choice=$(read_default "Do you want a randomized password or type it in? (random/type) " "random")
  pw_choice=${pw_choice,,}
  local pass=""
  if [[ "$pw_choice" == "type" || "$pw_choice" == "t" ]]; then
    # read password twice without echo
    if [ -t 0 ]; then
      read -rsp "Enter password for $username: " pass
      echo
      read -rsp "Confirm password: " pass2
      echo
      if [ "$pass" != "$pass2" ]; then
        echoerr "Passwords do not match. Aborting password set for user."
        return 1
      fi
    else
      echoerr "Non-interactive shell cannot accept typed password. Aborting."
      return 1
    fi
  else
    # randomized password
    local want_len
    want_len=$(read_default "Randomized password length" "11")
    # validate numeric
    if ! [[ "$want_len" =~ ^[0-9]+$ ]] || [ "$want_len" -le 0 ]; then
      echoerr "Invalid length. Using default 11."
      want_len=11
    fi
    pass=$(rand_alnum "$want_len")
    local passfile="/root/.${username}.pass"
    if ! printf "%s\n" "$pass" >"$passfile"; then
      echoerr "Failed to write password file $passfile"
      return 1
    fi
    chmod 600 "$passfile"
    CREATED_FILES+=("$passfile")
    echoinfo "Randomized password created and saved to $passfile"
  fi

  # set password
  if ! echo "$username:$pass" | chpasswd; then
    echoerr "Failed to set password for $username."
    return 1
  fi

  # add to wheel group (or sudo fallback)
  if getent group wheel >/dev/null; then
    usermod -aG wheel "$username" || echoinfo "Warning: couldn't add $username to wheel (usermod failed)."
    echoinfo "Added $username to group 'wheel'."
  else
    # add to sudo if wheel not present
    if getent group sudo >/dev/null; then
      usermod -aG sudo "$username" || echoinfo "Warning: couldn't add $username to sudo (usermod failed)."
      echoinfo "Group 'wheel' not present — added $username to 'sudo' group instead."
    else
      echoinfo "Neither 'wheel' nor 'sudo' groups exist on this system. No group added."
    fi
  fi

  printf "\n==== USER '%s' PASSWORD ====\n%s\n===============================\n\n" "$username" "$pass"
  # record username for optional switch
  NEW_USER="$username"
  return 0
}
run_step "Create new user (optional) and set password" step_create_user || true

# ---- STEP 3: hostname ----
step_set_hostname() {
  local cur_host
  cur_host=$(hostnamectl --static 2>/dev/null || hostname)
  local new_host
  new_host=$(read_default "Enter new hostname" "$cur_host")
  if [ -z "$new_host" ] || [ "$new_host" = "$cur_host" ]; then
    echoinfo "Hostname unchanged."
    return 0
  fi

  if ! hostnamectl set-hostname "$new_host"; then
    echoerr "hostnamectl failed to set hostname to $new_host"
    return 1
  fi

  # try restarting hostnamed or hostname service
  if systemctl is-active --quiet systemd-hostnamed; then
    systemctl restart systemd-hostnamed || echoinfo "Warning: could not restart systemd-hostnamed (non-fatal)."
  fi

  echoinfo "Hostname changed to $new_host"
  return 0
}
run_step "Prompt and set hostname" step_set_hostname || true

# ---- STEP 4: set up network (static IPv4 using netplan if present) ----
step_set_network() {
  local want_static
  want_static=$(read_default "Do you want to configure a static IPv4? (y/n)" "n")
  want_static=${want_static,,}
  if [[ "$want_static" != "y" && "$want_static" != "yes" ]]; then
    echoinfo "Skipping static network configuration."
    return 0
  fi

  # Only attempt netplan. If not present, show info and skip (safe behavior).
  if [ ! -d /etc/netplan ]; then
    echoerr "Netplan not detected on this system. This script only supports automatic static IP using netplan. Skipping network configuration."
    return 1
  fi

  # discover primary interface (best-effort)
  local IFACE
  IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk -- '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1); exit}}}' || true)
  IFACE=${IFACE:-$(ip -o -4 addr show scope global | awk '{print $2; exit}')}
  IFACE=${IFACE:-"eth0"}

  # current ip, gateway, nameservers
  local CUR_IP CUR_GW CUR_DNS CUR_SEARCH
  CUR_IP=$(ip -4 addr show dev "$IFACE" 2>/dev/null | awk '/inet /{print $2}' | head -n1)
  CUR_GW=$(ip route | awk '/default/ {print $3; exit}')
  # resolv.conf
  CUR_DNS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf || true)
  CUR_SEARCH=$(awk '/^search/ {for(i=2;i<=NF;i++) printf "%s%s",$i,(i==NF?"" "":" "); print ""; exit}' /etc/resolv.conf || true)

  echoinfo "Detected interface: $IFACE"
  echoinfo "Current IP: ${CUR_IP:-(none)}"
  echoinfo "Current gateway: ${CUR_GW:-(none)}"
  echoinfo "Current nameserver: ${CUR_DNS:-(none)}"
  echoinfo "Current search domains: ${CUR_SEARCH:-(none)}"

  local ask_subnet ask_addr ask_gw ask_dns ask_search
  ask_subnet=$(read_default "IPv4 subnet (CIDR) for $IFACE (example: 192.168.1.50/24)" "${CUR_IP:-}")
  ask_addr="$ask_subnet"
  ask_gw=$(read_default "Gateway for $IFACE" "${CUR_GW:-}")
  ask_dns=$(read_default "Nameserver(s) (space-separated)" "${CUR_DNS:-}")
  ask_search=$(read_default "Search domain(s) (space-separated)" "${CUR_SEARCH:-}")

  # Validate minimal fields
  if [ -z "$ask_addr" ] || [ -z "$ask_gw" ]; then
    echoerr "Address or gateway not provided. Aborting netplan static configuration."
    return 1
  fi

  local NETPLAN_FILE="/etc/netplan/01-static-ip.yaml"
  echoinfo "Writing netplan config to $NETPLAN_FILE (backup saved if exists)."

  if [ -f "$NETPLAN_FILE" ]; then
    cp -a "$NETPLAN_FILE" "${NETPLAN_FILE}.bak.$(date +%s)" || true
  fi

  # build nameserver list YAML
  local ns_yaml=""
  if [ -n "$ask_dns" ]; then
    # split on spaces
    IFS=' ' read -r -a dnsarr <<<"$ask_dns"
    for d in "${dnsarr[@]}"; do
      ns_yaml+="      - ${d}\n"
    done
  fi

  local search_yaml=""
  if [ -n "$ask_search" ]; then
    IFS=' ' read -r -a sarr <<<"$ask_search"
    for s in "${sarr[@]}"; do
      search_yaml+="      - ${s}\n"
    done
  fi

  # Write netplan file
  cat >"$NETPLAN_FILE" <<EOF
# Generated by setup-helper.sh
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: false
      addresses: [ ${ask_addr} ]
      gateway4: ${ask_gw}
      nameservers:
$(printf "%b" "$ns_yaml")
$(if [ -n "$search_yaml" ]; then printf "        search:\n$(printf "%b" "$search_yaml")"; fi)
EOF

  chmod 644 "$NETPLAN_FILE" || true

  # apply netplan
  if ! netplan apply; then
    echoerr "netplan apply failed. Please inspect $NETPLAN_FILE and run 'netplan try'/'netplan apply' manually."
    return 1
  fi

  echoinfo "Netplan applied successfully."
  return 0
}
run_step "Configure static IPv4 (netplan)" step_set_network || true

# ---- STEP 5: finishing up ----
step_finish() {
  echoinfo "Finishing up..."

  # list created files
  if [ ${#CREATED_FILES[@]} -gt 0 ]; then
    echoinfo "Created password file(s):"
    for f in "${CREATED_FILES[@]}"; do
      printf " - %s\n" "$f"
    done
  else
    echoinfo "No password files were created by this script."
  fi

  # prompt to switch user if created
  if [ -n "${NEW_USER:-}" ]; then
    local switch_ans
    switch_ans=$(read_default "Do you want to switch to user '$NEW_USER' and change to their home directory now? (y/n)" "n")
    switch_ans=${switch_ans,,}
    if [[ "$switch_ans" == "y" || "$switch_ans" == "yes" ]]; then
      echoinfo "Switching to $NEW_USER (use 'exit' to come back to root)."
      # su into user and change to their home
      exec su - "$NEW_USER"
      # exec will replace the script; if it fails, fallthrough
      echoerr "Failed to su - $NEW_USER. You remain root."
    else
      echoinfo "Not switching user now."
    fi
  fi

  echoinfo "All done. Review created files above. If you changed networking or hostname you may want to reboot."
}
run_step "Finalizing and optional user switch" step_finish || true

# End of script
