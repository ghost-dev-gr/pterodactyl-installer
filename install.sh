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

# Custom ASCII Art

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
    echo -e -n "* Installation of $1 completed. Do you want to proceed to $2 installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      run "$2"
    else
      fail "Installation of $2 aborted."
      exit 1
    fi
  fi
}

# Main Menu
done=false
while [ "$done" == false ]; do
  options=(
    "Install the panel"
    "Install Wings"
    "Install both [0] and [1] on the same machine (wings script runs after panel)"

  )

  actions=(
    "panel"
    "wings"
    "panel;wings"

  )

  # Display options with custom design
  echo -e "${BOLD}${GREEN}Select the operation you wish to perform:${NC}"
  echo -e "${RED}-----------------------------------------------${NC}"

  for i in "${!options[@]}"; do
    echo -e "${BOLD}${BLUE}[${i}]${NC} ${options[$i]}"
  done

  echo -e "${RED}-----------------------------------------------${NC}"
  echo -n "* Please input a number from 0-$((${#actions[@]} - 1)): "
  read -r action

  # Validate input
  [ -z "$action" ] && echo -e "${RED}Input is required! Please try again.${NC}" && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  if [[ ! " ${valid_input[*]} " =~ ${action} ]]; then
    echo -e "${RED}Invalid option! Please try again.${NC}"
    continue
  fi

  # Execute the chosen action
  done=true
  IFS=";" read -r i1 i2 <<<"${actions[$action]}"
  execute "$i1" "$i2"
done

# Clean up lib.sh after use
rm -rf /tmp/lib.sh

echo -e "${GREEN}Installation process completed!${NC}"
