#!/bin/bash

set -e

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
  echo -e "${BOLD}${YELLOW}  ___       ______                               ______       ______  ___      _________          ________             _________________              ________________    "
  echo -e "${BOLD}${YELLOW}  __ |     / /__(_)_____________ ________ __________  /_      ___   |/  /_____ ______  /____      ___  __ )____  __    _  /_  ____/__  /________________  /______/_/_ \  "
  echo -e "${BOLD}${YELLOW}  __ | /| / /__  /__  __ \_  __ \/_  ___/ __  ___/_  __ \     __  /|_/ /_  __ \/  __  /_  _ \     __  __  |_  / / /    / /_  / __ __  __ \  __ \_  ___/  __/___/_/ ___ \ "
  echo -e "${BOLD}${YELLOW}  __ |/ |/ / _  / _  / / /  /_/ /_(__  )___(__  )_  / / /     _  /  / / / /_/ // /_/ / /  __/     _  /_/ /_  /_/ /     \ \/ /_/ / _  / / / /_/ /(__  )/ /_ __/_/   __  / "
  echo -e "${BOLD}${YELLOW} ____/|__/  /_/  /_/ /_/_\__, / /____/_(_)____/ /_/ /_/      /_/  /_/  \__,_/ \__,_/  \___/      /_____/ _\__, /       \_\____/  /_/ /_/\____//____/ \__/ /_/     _/_/  "
  echo -e "${BOLD}${YELLOW}                        /____/                                                                           /____/                                                          "
  echo -e "${NC}${RED}-----------------------------------------------"

  echo -e "${YELLOW}    This script is not associated with the official Pterodactyl Project. And will only be used by the creators"
  echo -e "${YELLOW}    Pterodactyl panel installation script Lib.sh"
  echo -e "${YELLOW}    Copyright (C) 2024 - 2025, Naoum Galatas, <naoumgalatas43@gmail.com>"
  echo -e "${YELLOW}    Running $OS version $OS_VER. "
  echo -e "${RED}-----------------------------------------------"
  log "Latest pterodactyl/wings is $PTERODACTYL_WINGS_VERSION"
  generate_brake 70
}
greet()
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

# Install mariadb
export INSTALL_MARIADB=false

# Firewall
export CONFIGURE_FIREWALL=false

# SSL (Let's Encrypt)
export CONFIGURE_LETSENCRYPT=false
export FQDN=""
export EMAIL=""

# Database host
export CONFIGURE_DBHOST=false
export CONFIGURE_DB_FIREWALL=false
export MYSQL_DBHOST_HOST="127.0.0.1"
export MYSQL_DBHOST_USER="pterodactyluser"
export MYSQL_DBHOST_PASSWORD=""

# ------------ User input functions ------------ #

request_certificate() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    alert "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
  fi

  alert "You cannot use Let's Encrypt with your hostname as an IP address! It must be a FQDN (e.g. node.example.org)."

  echo -e -n "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): "
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  fi
}

ask_database_user() {
  echo -n "* Do you want to automatically configure a user for database hosts? (y/N): "
  read -r CONFIRM_DBHOST

  if [[ "$CONFIRM_DBHOST" =~ [Yy] ]]; then
    ask_database_external
    CONFIGURE_DBHOST=true
  fi
}

ask_database_external() {
  echo -n "* Do you want to configure MySQL to be accessed externally? (y/N): "
  read -r CONFIRM_DBEXTERNAL

  if [[ "$CONFIRM_DBEXTERNAL" =~ [Yy] ]]; then
    echo -n "* Enter the panel address (blank for any address): "
    read -r CONFIRM_DBEXTERNAL_HOST
    if [ "$CONFIRM_DBEXTERNAL_HOST" == "" ]; then
      MYSQL_DBHOST_HOST="%"
    else
      MYSQL_DBHOST_HOST="$CONFIRM_DBEXTERNAL_HOST"
    fi
    [ "$CONFIGURE_FIREWALL" == true ] && ask_database_firewall
    return 0
  fi
}

ask_database_firewall() {
  alert "Allow incoming traffic to port 3306 (MySQL) can potentially be a security risk, unless you know what you are doing!"
  echo -n "* Would you like to allow incoming traffic to port 3306? (y/N): "
  read -r CONFIRM_DB_FIREWALL
  if [[ "$CONFIRM_DB_FIREWALL" =~ [Yy] ]]; then
    CONFIGURE_DB_FIREWALL=true
  fi
}

####################
## MAIN FUNCTIONS ##
####################

main() {
  # check if we can detect an already existing installation
  if [ -d "/etc/pterodactyl" ]; then
    alert "The script has detected that you already have Pterodactyl wings on your system! You cannot run the script multiple times, it will fail!"
    echo -e -n "* Are you sure you want to proceed? (y/N): "
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      fail "Installation aborted!"
      exit 1
    fi
  fi

  greet "wings"

  check_virt

  echo "* "
  echo "* The installer will install Docker, required dependencies for Wings"
  echo "* as well as Wings itself. But it's still required to create the node"
  echo "* on the panel and then place the configuration file on the node manually after"
  echo "* the installation has finished. Read more about this process on the"
  echo "* official documentation: $(linkify 'https://pterodactyl.io/wings/1.0/installing.html#configure')"
  echo "* "
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not start Wings automatically (will install systemd service, not start it)."
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: this script will not enable swap (for docker)."
  generate_brake 42

  ask_firewall CONFIGURE_FIREWALL

  ask_database_user

  if [ "$CONFIGURE_DBHOST" == true ]; then
    type mysql >/dev/null 2>&1 && HAS_MYSQL=true || HAS_MYSQL=false

    if [ "$HAS_MYSQL" == false ]; then
      INSTALL_MARIADB=true
    fi

    MYSQL_DBHOST_USER="-"
    while [[ "$MYSQL_DBHOST_USER" == *"-"* ]]; do
      required_input MYSQL_DBHOST_USER "Database host username (pterodactyluser): " "" "pterodactyluser"
      [[ "$MYSQL_DBHOST_USER" == *"-"* ]] && fail "Database user cannot contain hyphens"
    done

    password_input MYSQL_DBHOST_PASSWORD "Database host password: " "Password cannot be empty"
  fi

  request_certificate

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    while [ -z "$FQDN" ]; do
      echo -n "* Set the FQDN to use for Let's Encrypt (node.example.com): "
      read -r FQDN

      ASK=false

      [ -z "$FQDN" ] && fail "FQDN cannot be empty"                                                            # check if FQDN is empty
      bash <(curl -s "$GITHUB_URL"/lib/verify-fqdn.sh) "$FQDN" || ASK=true                                      # check if FQDN is valid
      [ -d "/etc/letsencrypt/live/$FQDN/" ] && fail "A certificate with this FQDN already exists!" && ASK=true # check if cert exists

      [ "$ASK" == true ] && FQDN=""
      [ "$ASK" == true ] && echo -e -n "* Do you still want to automatically configure HTTPS using Let's Encrypt? (y/N): "
      [ "$ASK" == true ] && read -r CONFIRM_SSL

      if [[ ! "$CONFIRM_SSL" =~ [Yy] ]] && [ "$ASK" == true ]; then
        CONFIGURE_LETSENCRYPT=false
        FQDN=""
      fi
    done
  fi

  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    # set EMAIL
    while ! verify_email "$EMAIL"; do
      echo -n "* Enter email address for Let's Encrypt: "
      read -r EMAIL

      verify_email "$EMAIL" || fail "Email cannot be empty or invalid"
    done
  fi

  echo -n "* Proceed with installation? (y/N): "

  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    execute_installer "wings"
  else
    fail "Installation aborted."
    exit 1
  fi
}

function goodbye {
  echo ""
  generate_brake 70
  echo "* Wings installation completed"
  echo "*"
  echo "* To continue, you need to configure Wings to run with your panel"
  echo "* Please refer to the official guide, $(linkify 'https://pterodactyl.io/wings/1.0/installing.html#configure')"
  echo "* "
  echo "* You can either copy the configuration file from the panel manually to /etc/pterodactyl/config.yml"
  echo "* or, you can use the \"auto deploy\" button from the panel and simply paste the command in this terminal"
  echo "* "
  echo "* You can then start Wings manually to verify that it's working"
  echo "*"
  echo "* sudo wings"
  echo "*"
  echo "* Once you have verified that it is working, use CTRL+C and then start Wings as a service (runs in the background)"
  echo "*"
  echo "* systemctl start wings"
  echo "*"
  echo -e "* ${COLOR_RED}Note${COLOR_NC}: It is recommended to enable swap (for Docker, read more about it in official documentation)."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured your firewall, ports 8080 and 2022 needs to be open."
  generate_brake 70
  echo ""
}

# run script
main
goodbye
