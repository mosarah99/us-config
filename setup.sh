#!/usr/bin/env bash
# Ubuntu Server Minimal Setup Script (Interactive + Unattended)
# Features:
#  - Optional root password update (typed or randomized)
#  - Optional user creation
#  - Hostname configuration
#  - Optional static IP config
#  - Non-interactive mode via ENV vars or command-line flags

set -euo pipefail

# ---------------- Colors ----------------
RED="\e[1;31m"
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;34m"
BOLD="\e[1m"
RESET="\e[0m"

# ---------------- Helpers ----------------
log()    { echo -e "${GREEN}[INFO]${RESET} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
highlight() { echo -e "${BOLD}${BLUE}$*${RESET}"; }

default() { echo -n "$1"; }

pause() {
  if [[ "${UNATTENDED:-0}" -eq 0 ]]; then
    read -rp "Press Enter to continue..."
  fi
}

# Random string generator
gen_pass() {
  local len=${1:-12}
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c "$len"
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
  fi
}

# ---------------- Argument Parsing ----------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --unattended) UNATTENDED=1 ;;
    --hostname=*) HOSTNAME_NEW="${1#*=}" ;;
    --user=*) NEWUSER="${1#*=}" ;;
    --user-pass=*) USER_PASS="${1#*=}" ;;
    --root-pass=*) ROOT_PASS_MANUAL="${1#*=}" ;;
    --static-ip) SET_STATIC="y" ;;
    *) warn "Unknown option $1" ;;
  esac
  shift
done

UNATTENDED=${UNATTENDED:-0}

# ---------------- STEP 0: System Update ----------------
highlight "\n=== STEP 0: Updating System ==="
if ! sudo apt update && sudo apt upgrade -y; then
  error "System update failed, skipping..."
fi

# ---------------- STEP 1: Root Password ----------------
highlight "\n=== STEP 1: Root Password Configuration ==="
ROOT_PASS_FILE="/root/.root.pass"

SET_ROOT_PASS=${SET_ROOT_PASS:-n}
if [[ $UNATTENDED -eq 0 ]]; then
  read -rp "Do you want to set a new password for root? [y/N]: " SET_ROOT_PASS
  SET_ROOT_PASS=${SET_ROOT_PASS,,:-n}
fi

if [[ "$SET_ROOT_PASS" == "y" || "$SET_ROOT_PASS" == "yes" ]]; then
  MODE=${ROOT_PASS_MODE:-r}
  if [[ $UNATTENDED -eq 0 ]]; then
    read -rp "Randomized or typed password? [R/t]: " MODE
    MODE=${MODE,,:-r}
  fi

  if [[ "$MODE" == "r" || "$MODE" == "random" ]]; then
    ROOT_PASS_LEN=${ROOT_PASS_LEN:-14}
    ROOT_PASS=$(gen_pass "$ROOT_PASS_LEN")
    echo "$ROOT_PASS" | sudo tee "$ROOT_PASS_FILE" >/dev/null
  else
    if [[ $UNATTENDED -eq 0 ]]; then
      read -srp "Enter new root password: " ROOT_PASS
      echo
    else
      ROOT_PASS=${ROOT_PASS_MANUAL:-$(gen_pass 14)}
    fi
  fi

  if echo "root:${ROOT_PASS}" | sudo chpasswd; then
    chmod 600 "$ROOT_PASS_FILE" 2>/dev/null || true
    log "Root password updated successfully."
    echo -e "New root password: ${RED}${BOLD}${ROOT_PASS}${RESET}"
  else
    error "Failed to update root password."
  fi
else
  log "Skipping root password update."
fi

# ---------------- STEP 2: Create User ----------------
highlight "\n=== STEP 2: User Creation ==="
CREATE_USER=${CREATE_USER:-n}
if [[ $UNATTENDED -eq 0 ]]; then
  read -rp "Do you want to create a new user? [y/N]: " CREATE_USER
  CREATE_USER=${CREATE_USER,,:-n}
fi

if [[ "$CREATE_USER" == "y" || "$CREATE_USER" == "yes" ]]; then
  if [[ $UNATTENDED -eq 0 ]]; then
    read -rp "Enter username: " NEWUSER
  fi
  if [[ -z "${NEWUSER:-}" ]]; then
    warn "No username specified; skipping user creation."
  else
    if id "$NEWUSER" >/dev/null 2>&1; then
      warn "User $NEWUSER already exists; skipping."
    else
      USER_PASS_MODE=${USER_PASS_MODE:-r}
      if [[ $UNATTENDED -eq 0 ]]; then
        read -rp "Randomized or typed password? [R/t]: " USER_PASS_MODE
        USER_PASS_MODE=${USER_PASS_MODE,,:-r}
      fi

      if [[ "$USER_PASS_MODE" == "r" ]]; then
        USER_PASS_LEN=${USER_PASS_LEN:-11}
        USER_PASS=$(gen_pass "$USER_PASS_LEN")
        echo "$USER_PASS" | sudo tee "/root/.${NEWUSER}.pass" >/dev/null
        chmod 600 "/root/.${NEWUSER}.pass"
      else
        if [[ $UNATTENDED -eq 0 ]]; then
          read -srp "Enter password for $NEWUSER: " USER_PASS
          echo
        fi
      fi

      sudo adduser --disabled-password --gecos "" "$NEWUSER"
      echo "$NEWUSER:${USER_PASS}" | sudo chpasswd
      sudo usermod -aG sudo "$NEWUSER" || sudo usermod -aG wheel "$NEWUSER"
      log "User ${NEWUSER} created."
      echo -e "Password for ${BOLD}${NEWUSER}${RESET}: ${YELLOW}${USER_PASS}${RESET}"
    fi
  fi
else
  log "Skipping user creation."
  NEWUSER=""
fi

# ---------------- STEP 3: Hostname ----------------
highlight "\n=== STEP 3: Hostname Setup ==="
CURRENT_HOST=$(hostname)
if [[ $UNATTENDED -eq 0 ]]; then
  read -rp "Enter new hostname [default: ${CURRENT_HOST}]: " HOSTNAME_NEW
fi
HOSTNAME_NEW=${HOSTNAME_NEW:-$CURRENT_HOST}

if [[ "$HOSTNAME_NEW" != "$CURRENT_HOST" ]]; then
  echo "$HOSTNAME_NEW" | sudo tee /etc/hostname >/dev/null
  sudo hostnamectl set-hostname "$HOSTNAME_NEW" || error "Hostname change failed."
  sudo systemctl restart systemd-logind.service || true
  log "Hostname changed to ${HOSTNAME_NEW}"
else
  log "Hostname unchanged."
fi

# ---------------- STEP 4: Static IP ----------------
highlight "\n=== STEP 4: Network Configuration ==="
if [[ $UNATTENDED -eq 0 ]]; then
  read -rp "Set static IP? [y/N]: " SET_STATIC
  SET_STATIC=${SET_STATIC,,:-n}
fi

if [[ "$SET_STATIC" == "y" || "$SET_STATIC" == "yes" ]]; then
  IFACE=$(ip -o -4 route show to default | awk '{print $5}')
  CURRENT_IP=$(hostname -I | awk '{print $1}')
  CURRENT_GW=$(ip route | awk '/default/ {print $3}')
  CURRENT_DNS=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | paste -sd "," -)
  CURRENT_SEARCH=$(grep "search" /etc/resolv.conf | awk '{$1=""; print $0}' | xargs)

  [[ $UNATTENDED -eq 0 ]] && read -rp "IPv4 Address [${CURRENT_IP}]: " IPADDR
  [[ $UNATTENDED -eq 0 ]] && read -rp "Gateway [${CURRENT_GW}]: " GATEWAY
  [[ $UNATTENDED -eq 0 ]] && read -rp "Nameservers [${CURRENT_DNS}]: " DNS
  [[ $UNATTENDED -eq 0 ]] && read -rp "Search domains [${CURRENT_SEARCH}]: " SEARCH

  IPADDR=${IPADDR:-$CURRENT_IP}
  GATEWAY=${GATEWAY:-$CURRENT_GW}
  DNS=${DNS:-$CURRENT_DNS}
  SEARCH=${SEARCH:-$CURRENT_SEARCH}

  NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
  sudo tee "$NETPLAN_FILE" >/dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses: [${IPADDR}/24]
      gateway4: ${GATEWAY}
      nameservers:
        addresses: [${DNS}]
        search: [${SEARCH}]
EOF

  if sudo netplan apply; then
    log "Static IP configured on ${IFACE}"
  else
    error "Static IP setup failed. Reverting to DHCP..."
    sudo sed -i 's/dhcp4: no/dhcp4: yes/' "$NETPLAN_FILE"
    sudo netplan apply || error "Network recovery failed!"
  fi
else
  log "Skipping network configuration."
fi

# ---------------- STEP 5: Finishing ----------------
highlight "\n=== STEP 5: Finishing Up ==="
if [[ -n "${NEWUSER}" && $UNATTENDED -eq 0 ]]; then
  read -rp "Switch to user '${NEWUSER}'? [y/N]: " SWITCH
  if [[ "${SWITCH,,}" == "y" ]]; then
    log "Switching to ${NEWUSER}..."
    sudo -i -u "$NEWUSER"
  fi
fi

log "Password files created:"
ls -l /root/.*.pass 2>/dev/null || echo "None found."
highlight "\nSetup completed successfully!\n"
