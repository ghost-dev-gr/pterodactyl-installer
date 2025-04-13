#!/bin/bash

set -e

if [ -f /root/build.sh ]; then
    source /root/build.sh
else
    echo "[x] Missing /root/build.sh - Cannot continue!"
    exit 1
fi

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

# ------------------ Variables ----------------- #

# Install mariadb
export INSTALL_MARIADB=false

# Firewall
export CONFIGURE_FIREWALL=true

# SSL (Let's Encrypt)
export CONFIGURE_LETSENCRYPT=true
export FQDN="${NODEFQDN}"
export EMAIL="${user_email}"

# Database host
export CONFIGURE_DBHOST=false
export CONFIGURE_DB_FIREWALL=true
export MYSQL_DBHOST_HOST="127.0.0.1"
export MYSQL_DBHOST_USER="${db_user_user}"
export MYSQL_DBHOST_PASSWORD="${db_user_password}"

# ------------ User input functions ------------ #

request_certificate() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    alert "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk."
  fi

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  else
    CONFIGURE_LETSENCRYPT=false
  fi
}

ask_database_user() {
  if [[ "$CONFIRM_DBHOST" =~ [Yy] ]]; then
    CONFIGURE_DBHOST=true
    ask_database_external
  else
    CONFIGURE_DBHOST=false
  fi
}


ask_database_external() {
  if [[ "$CONFIRM_DBEXTERNAL" =~ [Yy] ]]; then
    if [ -z "$CONFIRM_DBEXTERNAL_HOST" ]; then
      MYSQL_DBHOST_HOST="%"
    else
      MYSQL_DBHOST_HOST="$CONFIRM_DBEXTERNAL_HOST"
    fi
    ask_database_firewall
  fi
}

ask_database_firewall() {
  if [[ "$CONFIRM_DB_FIREWALL" =~ [Yy] ]]; then
    CONFIGURE_DB_FIREWALL=true
  else
    CONFIGURE_DB_FIREWALL=false
  fi
}

####################
## MAIN FUNCTIONS ##
####################

main() {
  # check if we can detect an already existing installation
  if [ -d "/etc/pterodactyl" ]; then
    alert "The script has detected that you already have Pterodactyl wings on your system! You cannot run the script multiple times, it will fail!"
    fail "Installation aborted!"
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

  # Firewall
  CONFIGURE_FIREWALL=${CONFIGURE_FIREWALL:-true}

  # Database Host & Firewall
  CONFIGURE_DBHOST=false
  CONFIGURE_DB_FIREWALL=false

  if [[ "$CONFIRM_DBHOST" =~ [Yy] ]]; then
    CONFIGURE_DBHOST=true

    if [[ "$CONFIRM_DBEXTERNAL" =~ [Yy] ]]; then
      MYSQL_DBHOST_HOST="${CONFIRM_DBEXTERNAL_HOST:-%}"
      CONFIGURE_DB_FIREWALL=[[ "$CONFIRM_DB_FIREWALL" =~ [Yy] ]] && true || false
    fi
  fi

  # SSL
  CONFIGURE_LETSENCRYPT=false
  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
  fi

  # Email fallback if not set
  if [ "$CONFIGURE_LETSENCRYPT" == true ]; then
    if ! verify_email "$EMAIL"; then
      echo "[x] Invalid or missing email for Let's Encrypt, disabling SSL auto-config"
      CONFIGURE_LETSENCRYPT=false
    fi
  fi

  # If configuring DBHOST and MySQL isn't installed, mark to install MariaDB
  if [ "$CONFIGURE_DBHOST" == true ]; then
    type mysql >/dev/null 2>&1 || INSTALL_MARIADB=true

    # Sanitize database user (no hyphens allowed)
    if [[ "$MYSQL_DBHOST_USER" == *"-"* ]]; then
      fail "Database username must not contain hyphens: '$MYSQL_DBHOST_USER'"
    fi
  fi

  execute_installer "wings"
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
