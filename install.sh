#!/bin/bash

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
echo -e "${BOLD}${BLUE}     ___  ________      ___  ___      ________      ________       _________         ___  ___   "
echo -e "${BOLD}${BLUE}    /  /||\   ____\    |\  \|\  \    |\   __  \    |\   ____\     |\___   ___\      /  /||\  \ "
echo -e "${BOLD}${BLUE}   /  / /\ \  \___|    \ \  \\\  \   \ \  \|\  \   \ \  \___|_    \|___ \  \_|     /  // \ \  \ "
echo -e "${BOLD}${BLUE}  /  / /  \ \  \  ___   \ \   __  \   \ \  \\\  \   \ \_____  \        \ \  \     /  //   \ \  \ "
echo -e "${BOLD}${BLUE}  |\  \/    \ \  \|\  \   \ \  \ \  \   \ \  \\\  \   \|____|\  \        \ \  \   /  //     \/  /| "
echo -e "${BOLD}${BLUE}  \ \  \     \ \_______\   \ \__\ \__\   \ \_______\    ____\_\  \        \ \__\ /_ //      /  // "
echo -e "${BOLD}${BLUE}   \ \__\     \|_______|    \|__|\|__|    \|_______|   |\_________\        \|__||__|/      /_ //"
echo -e "${BOLD}${BLUE}    \|__|                                              \|_________|                       |__|/ "
echo -e "${NC}${RED}-----------------------------------------------"
echo -e "${YELLOW}     Welcome to the Custom Pterodactyl Installer ${NC}"
echo -e "${RED}-----------------------------------------------"

export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/phantom-dev-team/dragonfly-installer"

RECORD_FILE="/var/log/dragonfly-setup.log"

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  notify "* curl is needed for this setup to operate."
  notify "* install via apt (Debian/Ubuntu) or yum/dnf (RHEL)"
  exit 1
fi

# Remove previous helper file if present
[ -f /tmp/helper.sh ] && rm -rf /tmp/helper.sh
curl -sSL -o /tmp/helper.sh "$GITHUB_BASE_URL"/master/lib/helper.sh
# shellcheck source=lib/helper.sh
source /tmp/helper.sh

launch_process() {
  echo -e "\n\n* dragonfly-installer $(date) \n\n" >>$RECORD_FILE

  [[ "$1" == *"testing"* ]] && export GITHUB_SOURCE="main" && export SCRIPT_RELEASE="testing"
  refresh_helper_source
  start_interface "${1//_testing/}" |& tee -a $RECORD_FILE

  if [[ -n $2 ]]; then
    echo -e -n "* Setup of $1 done. Continue with $2 setup? (y/N): "
    read -r REPLY
    if [[ "$REPLY" =~ [Yy] ]]; then
      launch_process "$2"
    else
      fail "Setup of $2 cancelled."
      exit 1
    fi
  fi
}

display_intro ""

completed=no
while [ "$completed" == no ]; do
  selections=(
    "Setup the control panel"
    "Setup the daemon"
    "Setup both [0] and [1] on this system (daemon setup runs post panel)"
    # "Remove panel or daemon\n"

    "Setup panel using testing edition of this setup (unstable, may contain issues!)"
    "Setup daemon using testing edition of this setup (unstable, may contain issues!)"
    "Setup both [3] and [4] on this system (daemon setup runs post panel)"
    "Remove panel or daemon with testing edition of this setup (unstable, may contain issues!)"
  )

  operations=(
    "controlpanel"
    "daemon"
    "controlpanel;daemon"
    # "remove"

    "controlpanel_testing"
    "daemon_testing"
    "controlpanel_testing;daemon_testing"
    "remove_testing"
  )

  inform "What operation should we perform?"

  for idx in "${!selections[@]}"; do
    inform "[$idx] ${selections[$idx]}"
  done

  echo -n "* Choose 0-$((${#operations[@]} - 1)): "
  read -r choice

  [ -z "$choice" ] && fail "Selection required" && continue

  valid_choices=("$(for ((i = 0; i <= ${#operations[@]} - 1; i += 1)); do echo "${i}"; done)")
  [[ ! " ${valid_choices[*]} " =~ ${choice} ]] && fail "Invalid selection"
  [[ " ${valid_choices[*]} " =~ ${choice} ]] && completed=yes && IFS=";" read -r op1 op2 <<<"${operations[$choice]}" && launch_process "$op1" "$op2"
done

# Cleanup helper file
rm -rf /tmp/helper.sh
