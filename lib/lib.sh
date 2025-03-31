#!/bin/bash

set -e

# Colors for custom UI
NC="\033[0m"           # No Color
RED="\033[31m"         # Red
GREEN="\033[32m"       # Green
YELLOW="\033[33m"      # Yellow
BLUE="\033[34m"        # Blue
BOLD="\033[1m"         # Bold
UNDERLINE="\033[4m"    # Underline
                                                                                  
# ------------------ Variables ----------------- #

# Versioning
export GITHUB_SOURCE=${GITHUB_SOURCE:-master}
export SCRIPT_RELEASE=${SCRIPT_RELEASE:-canary}

# Pterodactyl versions
export PTERODACTYL_PANEL_VERSION=""
export PTERODACTYL_WINGS_VERSION=""

# Path (export everything that is possible, doesn't matter that it exists already)
export PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

# OS
export OS=""
export OS_VER_MAJOR=""
export CPU_ARCHITECTURE=""
export ARCH=""
export SUPPORTED=false

# download URLs
export PANEL_DL_URL="https://github.com/ghost-dev-gr/panel/releases/latest/download/panel.tar.gz"
export WINGS_DL_BASE_URL="https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_"
export MARIADB_URL="https://downloads.mariadb.com/MariaDB/mariadb_repo_setup"
export GITHUB_BASE_URL=${GITHUB_BASE_URL:-"https://raw.githubusercontent.com/dev-ghost-gr/pterodactyl-installer"}
export GITHUB_URL="$GITHUB_BASE_URL/$GITHUB_SOURCE"

# Colors
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'

# email input validation regex
email_regex="^(([A-Za-z0-9]+((\.|\-|\_|\+)?[A-Za-z0-9]?)*[A-Za-z0-9]+)|[A-Za-z0-9]+)@(([A-Za-z0-9]+)+((\.|\-|\_)?([A-Za-z0-9]+)+)*)+\.([A-Za-z]{2,})+$"

# Charset used to generate random passwords
password_charset='A-Za-z0-9!"#%&()*+,-./:;<=>?@[\]^_`{|}~'

# --------------------- Lib -------------------- #

lib_loaded() {
  return 0
}

# -------------- Visual functions -------------- #

log() {
  echo -e "* $1"
}

confirm() {
  echo ""
  log "${COLOR_GREEN}CONFIRMED${COLOR_NC}: $1"
  echo ""
}

fail() {
  echo ""
  echo -e "* ${COLOR_RED}FAILED${COLOR_NC}: $1" 1>&2
  echo ""
}

alert() {
  echo ""
  log "${COLOR_YELLOW}ALERT${COLOR_NC}: $1"
  echo ""
}

generate_brake() {
  for ((n = 0; n < $1; n++)); do
    echo -n "#"
  done
  echo ""
}

list_output() {
  generate_brake 30
  for word in $1; do
    log "$word"
  done
  generate_brake 30
  echo ""
}

linkify() {
  echo -e "\e]8;;${1}\a${1}\e]8;;\a"
}

# First argument is wings / panel / neither
greeting() {
  retrieve_latest_versions

  generate_brake 70
  echo -e "${BOLD}${RED}      __    _    __            __         __  ___           __             ___               __  _____   __             __      ____ "
  echo -e "${BOLD}${RED}     / /   (_)  / /      ___  / /        /  |/  / ___ _ ___/ / ___        / _ )  __ __      / / / ___/  / /  ___   ___ / /_   _/_/\ \ "
  echo -e "${BOLD}${RED}   / /__ / /  / _ \ _  (_-< / _ \      / /|_/ / / _ `// _  / / -_)      / _  | / // /     < < / (_ /  / _ \/ _ \ (_-</ __/ _/_/   > > "
  echo -e "${BOLD}${RED}  /____//_/  /_.__/(_)/___//_//_/     /_/  /_/  \_,_/ \_,_/  \__/      /____/  \_, /       \_\\___/  /_//_/\___//___/\__/ /_/    /_/  "
  echo -e "${NC}${YELLOW}-----------------------------------------------"

  echo -e "${YELLOW}    This script is not associated with the official Pterodactyl Project. And will only be used by the creators"
  echo -e "${YELLOW}    Pterodactyl panel installation script Lib.sh"
  echo -e "${YELLOW}    Copyright (C) 2024 - 2025, Naoum Galatas, <naoumgalatas43@gmail.com>"
  echo -e "${YELLOW}    Running $OS version $OS_VER. "
  echo -e "${YELLOW}-----------------------------------------------"
  if [ "$1" == "panel" ]; then
    log "Latest pterodactyl/panel is $PTERODACTYL_PANEL_VERSION"
  elif [ "$1" == "wings" ]; then
    log "Latest pterodactyl/wings is $PTERODACTYL_WINGS_VERSION"
  fi
  generate_brake 70
}

# ---------------- Lib functions --------------- #

retrieve_latest_release() {
  curl -sL "https://api.github.com/repos/$1/releases/latest" | #
    grep '"tag_name":' |                                       
    sed -E 's/.*"([^"]+)".*/\1/'                              
}

retrieve_latest_versions() {
  log "Retrieving release information..."
  PTERODACTYL_PANEL_VERSION=$(retrieve_latest_release "ghost-dev-gr/panel")
  PTERODACTYL_WINGS_VERSION=$(retrieve_latest_release "ghost-dev-gr/wings")
}

update_library_source() {
  GITHUB_URL="$GITHUB_BASE_URL/$GITHUB_SOURCE"
  rm -rf /tmp/lib.sh
  curl -sSL -o /tmp/lib.sh "$GITHUB_URL"/lib/lib.sh
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh
}

execute_installer() {
  bash <(curl -sSL "$GITHUB_URL/installers/$1.sh")
}

execute_ui() {
  bash <(curl -sSL "$GITHUB_URL/ui/$1.sh")
}

array_contains_item() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

verify_email() {
  [[ $1 =~ ${email_regex} ]]
}

check_ip() {
  ip route get "$1" >/dev/null 2>&1
  echo $?
}

generate_password() {
  local length=$1
  local password=""
  while [ ${#password} -lt "$length" ]; do
    password=$(echo "$password""$(head -c 100 /dev/urandom | LC_ALL=C tr -dc "$password_charset")" | fold -w "$length" | head -n 1)
  done
  echo "$password"
}

# -------------------- MYSQL ------------------- #

create_database_user() {
  local db_user_name="$1"
  local db_user_password="$2"
  local db_host="${3:-127.0.0.1}"

  log "Creating database user $db_user_name..."

  mariadb -u root -e "CREATE USER '$db_user_name'@'$db_host' IDENTIFIED BY '$db_user_password';"
  mariadb -u root -e "FLUSH PRIVILEGES;"

  log "Database user $db_user_name created"
}

grant_all_permissions() {
  local db_name="$1"
  local db_user_name="$2"
  local db_host="${3:-127.0.0.1}"

  log "Granting all permissions on $db_name to $db_user_name..."

  mariadb -u root -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user_name'@'$db_host' WITH GRANT OPTION;"
  mariadb -u root -e "FLUSH PRIVILEGES;"

  log "Permissions granted"
}

create_database() {
  local db_name="$1"
  local db_user_name="$2"
  local db_host="${3:-127.0.0.1}"

  log "Creating database $db_name..."

  mariadb -u root -e "CREATE DATABASE $db_name;"
  grant_all_permissions "$db_name" "$db_user_name" "$db_host"

  log "Database $db_name created"
}

# --------------- Package Manager -------------- #

# Argument for quite mode
update_repositories() {
  local args=""
  [[ $1 == true ]] && args="-qq"
  case "$OS" in
  ubuntu | debian)
    apt-get -y $args update
    ;;
  *)
    # Do nothing as AlmaLinux and RockyLinux update metadata before installing packages.
    ;;
  esac
}

# First argument list of packages to install, second argument for quite mode
install_dependencies() {
  local args=""
  if [[ $2 == true ]]; then
    case "$OS" in
    ubuntu | debian) args="-qq" ;;
    *) args="-q" ;;
    esac
  fi

  # Eval needed for proper expansion of arguments
  case "$OS" in
  ubuntu | debian)
    eval apt-get -y $args install "$1"
    ;;
  rocky | almalinux)
    eval dnf -y $args install "$1"
    ;;
  esac
}

# ------------ User input functions ------------ #

ensure_input() {
  local __resultvar=$1
  local result=''

  while [ -z "$result" ]; do
    echo -n "* ${2}"
    read -r result

    if [ -z "${3}" ]; then
      [ -z "$result" ] && result="${4}"
    else
      [ -z "$result" ] && fail "${3}"
    fi
  done

  eval "$__resultvar"'$result'""
}

email_prompt() {
  local __resultvar=$1
  local result=''

  while ! verify_email "$result"; do
    echo -n "* ${2}"
    read -r result

    verify_email "$result" || fail "${3}"
  done

  eval "$__resultvar"'$result'""
}

password_prompt() {
  local __resultvar=$1
  local result=''
  local default="$4"

  while [ -z "$result" ]; do
    echo -n "* ${2}"

    # modified from https://stackoverflow.com/a/22940001
    while IFS= read -r -s -n1 char; do
      [[ -z $char ]] && {
        printf '\n'
        break
      }                               # ENTER pressed; output \n and break.
      if [[ $char == $'\x7f' ]]; then # backspace was pressed
        # Only if variable is not empty
        if [ -n "$result" ]; then
          # Remove last char from output variable.
          [[ -n $result ]] && result=${result%?}
          # Erase '*' to the left.
          printf '\b \b'
        fi
      else
        # Add typed char to output variable.  [ -z "$result" ] && [ -n "
        result+=$char
        # Print '*' in its stead.
        printf '*'
      fi
    done
    [ -z "$result" ] && [ -n "$default" ] && result="$default"
    [ -z "$result" ] && fail "${3}"
  done

  eval "$__resultvar"'$result'""
}

# ------------------ Firewall ------------------ #

request_firewall() {
  local __resultvar=$1

  case "$OS" in
  ubuntu | debian)
    echo -e -n "* Do you want to automatically configure UFW (firewall)? (y/N): "
    read -r CONFIRM_UFW

    if [[ "$CONFIRM_UFW" =~ [Yy] ]]; then
      eval "$__resultvar"'true'""
    fi
    ;;
  rocky | almalinux)
    echo -e -n "* Do you want to automatically configure firewall-cmd (firewall)? (y/N): "
    read -r CONFIRM_FIREWALL_CMD

    if [[ "$CONFIRM_FIREWALL_CMD" =~ [Yy] ]]; then
      eval "$__resultvar"'true'""
    fi
    ;;
  esac
}

setup_firewall() {
  case "$OS" in
  ubuntu | debian)
    log ""
    log "Installing Uncomplicated Firewall (UFW)"

    if ! [ -x "$(command -v ufw)" ]; then
      update_repositories true
      install_dependencies "ufw" true
    fi

    ufw --force enable

    confirm "Enabled Uncomplicated Firewall (UFW)"

    ;;
  rocky | almalinux)

    log ""
    log "Installing FirewallD"

    if ! [ -x "$(command -v firewall-cmd)" ]; then
      install_dependencies "firewalld" true
    fi

    systemctl --now enable firewalld >/dev/null

    confirm "Enabled FirewallD"

    ;;
  esac
}

allow_ports_firewall() {
  case "$OS" in
  ubuntu | debian)
    for port in $1; do
      ufw allow "$port"
    done
    ufw --force reload
    ;;
  rocky | almalinux)
    for port in $1; do
      firewall-cmd --zone=public --add-port="$port"/tcp --permanent
    done
    firewall-cmd --reload -q
    ;;
  esac
}

# ---------------- System checks --------------- #

# panel x86_64 check
verify_os_x86_64() {
  if [ "${ARCH}" != "amd64" ]; then
    alert "Detected CPU architecture $CPU_ARCHITECTURE"
    alert "Using any other architecture than x86_64 is not supported!"
    exit 1
  fi
}

get_os_version() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  OS_VER_MAJOR=$(awk -F= '/^ID=/{print $2}' /etc/os-release)
  ARCH=$(uname -m)

  case "$OS" in
  ubuntu)
    SUPPORTED=true
    ;;
  debian)
    SUPPORTED=true
    ;;
  rocky)
    SUPPORTED=true
    ;;
  almalinux)
    SUPPORTED=true
    ;;
  *)
    SUPPORTED=false
    ;;
  esac
}

check_existing_files() {
  if [[ -f /etc/apt/sources.list ]]; then
    if grep -q 'pterodactyl' /etc/apt/sources.list; then
      fail "This script should not be run when Pterodactyl has been installed already."
    fi
  fi
}
