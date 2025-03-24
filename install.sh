#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'pterodactyl-installer'                                                    #
#                                                                                    #
# Copyright (C) 2018 - 2025, Vilhelm Prytz, <vilhelm@prytznet.se>                    #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# https://github.com/pterodactyl-installer/pterodactyl-installer/blob/master/LICENSE #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/ghost-dev-gr/pterodactyl-installer                     #
#                                                                                    #
######################################################################################

export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/ghost-dev-gr/pterodactyl-installer"

LOG_PATH="/var/log/pterodactyl-installer.log"

# Enhanced dependency checking
check_dependencies() {
  local missing=()
  for cmd in curl wget; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "* The following required commands are missing: ${missing[*]}"
    echo "* Attempting to install automatically..."
    
    if command -v apt-get &>/dev/null; then
      apt-get update && apt-get install -y "${missing[@]}" || {
        echo "* Automatic installation failed. Please install manually:"
        echo "  sudo apt-get install ${missing[*]}"
        exit 1
      }
    elif command -v yum &>/dev/null; then
      yum install -y "${missing[@]}" || {
        echo "* Automatic installation failed. Please install manually:"
        echo "  sudo yum install ${missing[*]}"
        exit 1
      }
    elif command -v dnf &>/dev/null; then
      dnf install -y "${missing[@]}" || {
        echo "* Automatic installation failed. Please install manually:"
        echo "  sudo dnf install ${missing[*]}"
        exit 1
      }
    else
      echo "* Could not determine package manager. Please install manually:"
      echo "  ${missing[*]}"
      exit 1
    fi
  fi
}

check_dependencies

# Robust lib.sh download with multiple fallbacks
download_lib() {
  local lib_urls=(
    "$GITHUB_BASE_URL/master/lib/lib.sh"
    "$GITHUB_BASE_URL/$GITHUB_SOURCE/lib/lib.sh"
    "https://cdn.jsdelivr.net/gh/ghost-dev-gr/pterodactyl-installer@master/lib/lib.sh"
  )

  # Clean up any existing file
  rm -f /tmp/lib.sh

  for url in "${lib_urls[@]}"; do
    echo "* Attempting to download lib.sh from $url"
    if curl -sSL -o /tmp/lib.sh "$url" || wget -q -O /tmp/lib.sh "$url"; then
      if [ -s "/tmp/lib.sh" ]; then
        echo "* Successfully downloaded lib.sh"
        return 0
      fi
      echo "* Downloaded empty file, trying next source..."
    else
      echo "* Download failed, trying next source..."
    fi
    sleep 1
  done

  echo -e "\n* ERROR: Failed to download lib.sh from all sources!"
  echo "* Possible reasons:"
  echo "  1. No internet connection"
  echo "  2. GitHub/CDN is down"
  echo "  3. Repository was moved/renamed"
  echo "* Please check your connection and try again."
  exit 1
}

# Validate and source lib.sh
load_lib() {
  if ! source /tmp/lib.sh; then
    echo "* ERROR: Failed to load lib.sh - file may be corrupted"
    echo "* Trying to download again..."
    download_lib
    if ! source /tmp/lib.sh; then
      echo "* FATAL: Still cannot load lib.sh"
      exit 1
    fi
  fi
}

# Main download and load process
download_lib
load_lib

execute() {
  echo -e "\n\n* pterodactyl-installer $(date) \n\n" >>$LOG_PATH

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  update_lib_source
  run_ui "${1//_canary/}" |& tee -a $LOG_PATH

  if [[ -n $2 ]]; then
    echo -e -n "* Installation of $1 completed. Do you want to proceed to $2 installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    else
      error "Installation of $2 aborted."
      exit 1
    fi
  fi
}

welcome ""

done=false
while [ "$done" == false ]; do
  options=(
    "Install the panel"
    "Install Wings"
    "Install both [0] and [1] on the same machine (wings script runs after panel)"
    # "Uninstall panel or wings\n"

    "Install panel with canary version of the script (the versions that lives in master, may be broken!)"
    "Install Wings with canary version of the script (the versions that lives in master, may be broken!)"
    "Install both [3] and [4] on the same machine (wings script runs after panel)"
    "Uninstall panel or wings with canary version of the script (the versions that lives in master, may be broken!)"
  )

  actions=(
    "panel"
    "wings"
    "panel;wings"
    # "uninstall"

    "panel_canary"
    "wings_canary"
    "panel_canary;wings_canary"
    "uninstall_canary"
  )

  output "What would you like to do?"

  for i in "${!options[@]}"; do
    output "[$i] ${options[$i]}"
  done

  echo -n "* Input 0-$((${#actions[@]} - 1)): "
  read -r action

  [ -z "$action" ] && error "Input is required" && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Invalid option"
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && IFS=";" read -r i1 i2 <<<"${actions[$action]}" && execute "$i1" "$i2"
done

# Remove lib.sh, so next time the script is run the, newest version is downloaded.
rm -rf /tmp/lib.sh
