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
clear
echo -e "${BOLD}${BLUE}      ___  ________      ___  ___      ________      ________       _________         ___  ___   "
echo -e "${BOLD}${BLUE}     /  /||\   ____\    |\  \|\  \    |\   __  \    |\   ____\     |\___   ___\      /  /||\  \ "
echo -e "${BOLD}${BLUE}    /  / /\ \  \___|    \ \  \\\  \   \ \  \|\  \   \ \  \___|_    \|___ \  \_|     /  // \ \  \ "
echo -e "${BOLD}${BLUE}   /  / /  \ \  \  ___   \ \   __  \   \ \  \\\  \   \ \_____  \        \ \  \     /  //   \ \  \ "
echo -e "${BOLD}${BLUE}  |\  \/    \ \  \|\  \   \ \  \ \  \   \ \  \\\  \   \|____|\  \        \ \  \   /  //     \/  /| "
echo -e "${BOLD}${BLUE}  \ \  \     \ \_______\   \ \__\ \__\   \ \_______\    ____\_\  \        \ \__\ /_ //      /  // "
echo -e "${BOLD}${BLUE}   \ \__\     \|_______|    \|__|\|__|    \|_______|   |\_________\        \|__||__|/      /_ //"
echo -e "${BOLD}${BLUE}    \|__|                                              \|_________|                       |__|/ "
echo -e "${NC}${RED}-----------------------------------------------"
echo -e "${YELLOW}     Welcome to the Custom Pterodactyl Installer ${NC}"
echo -e "${RED}-----------------------------------------------"


# Script Variables
export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/ghost-dev-gr/pterodactyl-installer"

LOG_PATH="/var/log/pterodactyl-installer.log"

# Set non-interactive mode for apt-get and other prompts
export DEBIAN_FRONTEND=noninteractive

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

  # Skip confirmation for next step, always assume yes
  if [[ -n $2 ]]; then
    echo "* Installation of $1 completed. Proceeding to $2 installation..."
    run "$2"
  fi
}

# Main Menu (skipping user interaction)
done=false

# Define actions to install both panel and wings automatically
run "panel" "wings"

# Clean up lib.sh after use
rm -rf /tmp/lib.sh

echo -e "${GREEN}Installation process completed!${NC}"

# Handle apt-get installation without prompts
echo -e "${YELLOW}Installing required packages without interaction...${NC}"
sudo apt-get update -y
sudo apt-get install -y curl git python3-pip

# Bypass any prompts that require "pressing Enter"
yes | sudo apt-get install -y netdata

