#!/bin/bash

set -e

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* FAIL: Could not load lib script" && exit 1
fi
if [ -f /root/build.sh ]; then
  source /root/variablesName.txt
else
  echo "build.sh not found, proceeding with default values."
fi
# ------------------ Variables ----------------- #

# Domain name / IP
export FQDN=""

# Default MySQL credentials
export MYSQL_DB=""
export MYSQL_USER=""
export MYSQL_PASSWORD=""

# Environment
export timezone=""
export email=""

# Initial admin account
export user_email=""
export user_username=""
export user_firstname=""
export user_lastname=""
export user_password=""

# Assume SSL, will fetch different config if true
export ASSUME_SSL=false
export CONFIGURE_LETSENCRYPT=false

# Firewall
export CONFIGURE_FIREWALL=false


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

  echo -e -n "${COLOR_YELLOW}* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  read -r CONFIRM_SSL

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
  read -r ASSUME_SSL_INPUT

  [[ "$ASSUME_SSL_INPUT" =~ [Yy] ]] && ASSUME_SSL=true
  true
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
    echo -e -n "${COLOR_YELLOW}* Are you sure you want to proceed? (y/N): "
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      fail "Installation aborted!"
      exit 1
    fi
  fi

  greet "panel"

  check_os_x86_64

  # set database credentials
  log "Database configuration."
  log ""
  log "This will be the credentials used for communication between the MySQL"
  log "database and the panel. You do not need to create the database"
  log "before running this script, the script will do that for you."
  log ""

  MYSQL_DB="-"
  while [[ "$MYSQL_DB" == *"-"* ]]; do
    required_input MYSQL_DB "Database name (panel): " "" "panel"
    [[ "$MYSQL_DB" == *"-"* ]] && fail "Database name cannot contain hyphens"
  done

  MYSQL_USER="-"
  while [[ "$MYSQL_USER" == *"-"* ]]; do
    required_input MYSQL_USER "Database username (pterodactyl): " "" "pterodactyl"
    [[ "$MYSQL_USER" == *"-"* ]] && fail "Database user cannot contain hyphens"
  done

  # MySQL password input
  rand_pw=$(gen_passwd 64)
  password_input MYSQL_PASSWORD "Password (press enter to use randomly generated password): " "MySQL password cannot be empty" "$rand_pw"

  readarray -t valid_timezones <<<"$(curl -s "$GITHUB_URL"/configs/valid_timezones.txt)"
  log "List of valid timezones here $(linkify "https://www.php.net/manual/en/timezones.php")"

  while [ -z "$timezone" ]; do
    echo -n "* Select timezone [Europe/Stockholm]: "
    read -r timezone_input

    array_contains_item "$timezone_input" "${valid_timezones[@]}" && timezone="$timezone_input"
    [ -z "$timezone_input" ] && timezone="Europe/Stockholm" # because köttbullar!
  done

  email_input email "Provide the email address that will be used to configure Let's Encrypt and Pterodactyl: " "Email cannot be empty or invalid"

  # Initial admin account
  email_input user_email "Email address for the initial admin account: " "Email cannot be empty or invalid"
  required_input user_username "Username for the initial admin account: " "Username cannot be empty"
  required_input user_firstname "First name for the initial admin account: " "Name cannot be empty"
  required_input user_lastname "Last name for the initial admin account: " "Name cannot be empty"
  password_input user_password "Password for the initial admin account: " "Password cannot be empty"

  generate_brake 72

  # set FQDN
  while [ -z "$FQDN" ]; do
    echo -n "* Set the FQDN of this panel (panel.example.com): "
    read -r FQDN
    [ -z "$FQDN" ] && fail "FQDN cannot be empty"
  done

  # Check if SSL is available
  check_FQDN_SSL

  # Ask if firewall is needed
  ask_firewall CONFIGURE_FIREWALL

  # Only ask about SSL if it is available
  if [ "$SSL_AVAILABLE" == true ]; then
    # Ask if letsencrypt is needed
    request_certificate
    # If it's already true, this should be a no-brainer
    [ "$CONFIGURE_LETSENCRYPT" == false ] && ssl_enabled
  fi

  # verify FQDN if user has selected to assume SSL or configure Let's Encrypt
  [ "$CONFIGURE_LETSENCRYPT" == true ] || [ "$ASSUME_SSL" == true ] && bash <(curl -s "$GITHUB_URL"/lib/verify-fqdn.sh) "$FQDN"

  # overview
  overview

  # confirm installation
  echo -e -n "\n${COLOR_YELLOW}* Initial configuration completed. Continue with installation? (y/N): "
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    execute_installer "panel"
  else
    fail "Installation aborted."
    exit 1
  fi
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

  [ "$CONFIGURE_LETSENCRYPT" == true ] && log "Your panel should be accessible from $(linkify "$FQDN")"
  [ "$ASSUME_SSL" == true ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && log "You have opted in to use SSL, but not via Let's Encrypt automatically. Your panel will not work until SSL has been configured."
  [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && log "Your panel should be accessible from $(linkify "$FQDN")"

  log ""
  log "Installation is using nginx on $OS"
  log "Thank you for using this script."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured the firewall: 80/443 (HTTP/HTTPS) is required to be open!"
  generate_brake 62
}

# run script
main
goodbye
