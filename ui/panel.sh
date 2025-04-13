#!/bin/bash

set -e

# Source the exported variables from build.sh
if [ -f /root/build.sh ]; then
    source /root/build.sh
else
    echo "[x] Missing /root/build.sh - Cannot continue!"
    exit 1
fi
# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* FAIL: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

# Domain name / IP (from build.sh)
export FQDN="${FQDN}"

# Default MySQL credentials (from build.sh)
export MYSQL_DB="${db_user_user}"
export MYSQL_USER="${db_user_user}"
export MYSQL_PASSWORD="${db_user_password}"

# Environment (from build.sh)
export timezone="${timezone}"
export email="${user_email}"

# Initial admin account (from build.sh)
export user_email="${user_email}"
export user_username="${user_username}"
export user_firstname="${user_firstname}"
export user_lastname="${user_lastname}"
export user_password="${user_password}"

# Assume SSL, will fetch different config if true
export ASSUME_SSL=false
export CONFIGURE_LETSENCRYPT=true

# Firewall
export CONFIGURE_FIREWALL=true


# Colors
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_NC='\033[0m'
COLOR_BOLD='\033[1m'

                                              

# ------------ Greet Message ------------ #
greet() {
  ret_last_version
  generate_brake 70
  echo -e "${BOLD}${YELLOW}  ________                   ______       ______       ______  ___      _________          ________             _________________              ________________    "
  echo -e "${BOLD}${YELLOW}  ___  __ \_____ _______________  /__________  /_      ___   |/  /_____ ______  /____      ___  __ )____  __    _  /_  ____/__  /________________  /______/_/_ \  "
  echo -e "${BOLD}${YELLOW}  __  /_/ /  __ \/_  __ \  _ \_  / __  ___/_  __ \     __  /|_/ /_  __ \/  __  /_  _ \     __  __  |_  / / /    / /_  / __ __  __ \  __ \_  ___/  __/___/_/ ___ \ "
  echo -e "${BOLD}${YELLOW}  _  ____// /_/ /_  / / /  __/  /___(__  )_  / / /     _  /  / / / /_/ // /_/ / /  __/     _  /_/ /_  /_/ /     \ \/ /_/ / _  / / / /_/ /(__  )/ /_ __/_/   __  / "
  echo -e "${BOLD}${YELLOW}  /_/     \__,_/ /_/ /_/\___//_/_(_)____/ /_/ /_/      /_/  /_/  \__,_/ \__,_/  \___/      /_____/ _\__, /       \_\____/  /_/ /_/\____//____/ \__/ /_/     _/_/  "
  echo -e "${BOLD}${YELLOW}                                                                                                  /____/           "
  echo -e "${NC}${RED}-----------------------------------------------"

  echo -e "${YELLOW}    This script is not associated with the official Pterodactyl Project. And will only be used by the creators"
  echo -e "${YELLOW}    Pterodactyl panel installation script Lib.sh"
  echo -e "${YELLOW}    Copyright (C) 2024 - 2025, Naoum Galatas, <naoumgalatas43@gmail.com>"
  echo -e "${YELLOW}    Running $OS version $OS_VER. "
  echo -e "${RED}-----------------------------------------------"
  log "Latest pterodactyl/panel is $PTERODACTYL_PANEL_VERSION"
 
  generate_brake 70
}
# ------------ User input functions ------------ #

request_certificate() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    alert "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
  fi
  local CONFIRM_SSL='y'

  echo -e -n "${COLOR_YELLOW}* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  #read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
    ASSUME_SSL=false
  fi
}

ssl_enabled() {
  log "Let's Encrypt is not going to be automatically configured by this script (user opted out)."
  log "You can 'assume' Let's Encrypt, which means the script will download a nginx configuration that is configured to use a Let's Encrypt certificate but the script won't obtain the certificate for you."
  log "If you assume SSL and do not obtain the certificate, your installation will not work."
  echo -n "${COLOR_YELLOW}* Assume SSL or not? (y/N): "
  local ASSUME_SSL_INPUT="${ASSUME_SSL}"
 
}

check_FQDN_SSL() {
  if [[ $(invalid_ip "$FQDN") == 1 && $FQDN != 'localhost' ]]; then
    SSL_AVAILABLE=true
  else
    alert "${COLOR_YELLOW}* Let's Encrypt will not be available for IP addresses."
    log "To use Let's Encrypt, you must use a valid domain name."
  fi
}

main() {
  # check if we can detect an already existing installation
  if [ -d "/var/www/pterodactyl" ]; then
    alert "The script has detected that you already have Pterodactyl panel on your system! You cannot run the script multiple times, it will fail!"
    fail "Installation aborted!"
  fi

  greet "panel"
  
  # Use the environment variables from build.sh for configuration
  MYSQL_DB="${db_user_user}"
  MYSQL_USER="${db_user_user}"
  MYSQL_PASSWORD="${db_user_password}"

  # Use default values from build.sh (no user input)
  email="${user_email}"
  user_email="${user_email}"
  user_username="${user_username}"
  user_firstname="${user_firstname}"
  user_lastname="${user_lastname}"
  user_password="${user_password}"

  # Check if SSL should be configured based on FQDN
  check_FQDN_SSL

  # Setup firewall if needed
  ask_firewall CONFIGURE_FIREWALL

  # Configure SSL if needed
  if [ "$SSL_AVAILABLE" == true ]; then
    request_certificate
    [ "$CONFIGURE_LETSENCRYPT" == false ] && ssl_enabled
  fi

  # Overview of the installation configuration
  overview

  # Confirm installation
  execute_installer "panel"
}


overview() {
  generate_brake 62
  log "Pterodactyl panel $PTERODACTYL_PANEL_VERSION with nginx on $OS"
  log "Database name: $MYSQL_DB"
  log "Database user: $MYSQL_USER"
  log "Database password: (censored)"
  log "Timezone: $timezone"
  log "Email: $email"
  log "User email: $user_email"
  log "Username: $user_username"
  log "First name: $user_firstname"
  log "Last name: $user_lastname"
  log "User password: (censored)"
  log "Hostname/FQDN: $FQDN"
  log "Configure Firewall? $CONFIGURE_FIREWALL"
  log "Configure Let's Encrypt? $CONFIGURE_LETSENCRYPT"
  log "Assume SSL? $ASSUME_SSL"
  generate_brake 62
}

goodbye() {
  generate_brake 62
  log "Panel installation completed"
  log ""

  [ "$CONFIGURE_LETSENCRYPT" == true ] && output "Your panel should be accessible from $(linkify "$FQDN")"
  [ "$ASSUME_SSL" == true ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && output "You have opted in to use SSL, but not via Let's Encrypt automatically. Your panel will not work until SSL has been configured."
  [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && output "Your panel should be accessible from $(linkify "$FQDN")"

  log ""
  log "Installation is using nginx on $OS"
  log "Thank you for using this script."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured the firewall: 80/443 (HTTP/HTTPS) is required to be open!"
  generate_brake 62
}

# run script
main
goodbye

