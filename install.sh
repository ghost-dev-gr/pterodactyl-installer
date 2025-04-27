#!/bin/bash

set -e

# Colors for custom UI
NC="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
BOLD="\033[1m"
UNDERLINE="\033[4m"

# Custom ASCII Art
clear
echo -e "${BOLD}${BLUE}      ___  ________      ___  ___      ________      ________       _________         ___  ___   "
echo -e "${BOLD}${BLUE}     /  /||\   ____\    |\  \|\  \    |\   __  \    |\   ____\     |\___   ___\      /  /||\  \ "
echo -e "${BOLD}${BLUE}    /  / /\ \  \___|    \ \  \\\  \   \ \  \|\  \   \ \  \___|_    \|___ \  \_|     /  // \ \  \ "
echo -e "${BOLD}${BLUE}   /  / /  \ \  \  ___   \ \   __  \   \ \  \\\  \   \ \_____  \        \ \  \     /  //   \ \  \ "
echo -e "${BOLD}${BLUE}  |\  \/    \ \  \|\  \   \ \  \ \  \   \ \  \\\  \   \|____|\  \        \ \  \   /  //     \/  /| "
echo -e "${BOLD}${BLUE}  \ \  \     \ \_______\   \ \__\ \__\   \ \_______\    ____\_\  \        \ \__\ /_ //      /  // "
echo -e "${BOLD}${BLUE}   \ \__\     \|_______|    \|__|\|__|    \|_______|   |\_________\        \|__||__|/      /_ // "
echo -e "${BOLD}${BLUE}    \|__|                                              \|_________|                       |__|/ "
echo -e "${NC}${RED}-----------------------------------------------"
echo -e "${YELLOW}     Welcome to the Custom Pterodactyl Installer ${NC}"
echo -e "${RED}-----------------------------------------------"

# Script Variables
export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/ghost-dev-gr/pterodactyl-installer"

LOG_PATH="/var/log/pterodactyl-installer.log"

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi

# Always remove lib.sh, before downloading it
[ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
# shellcheck source=lib/lib.sh
source /tmp/lib.sh

run() {
  echo -e "\n\n* pterodactyl-installer $(date) \n\n" >>$LOG_PATH

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  rev_lib_source
  execute_ui "${1//_canary/}" |& tee -a $LOG_PATH

  if [[ -n $2 ]]; then
    run "$2"
  fi
}

# FORCE: install both panel and wings
echo -e "${GREEN}Installing both the Panel and Wings automatically...${NC}"

execute "panel"
execute "wings"

# Clean up lib.sh after use
rm -rf /tmp/lib.sh

echo -e "${GREEN}Installation process completed!${NC}"
