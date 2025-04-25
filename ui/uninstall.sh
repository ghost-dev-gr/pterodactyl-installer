#!/bin/bash

set -e


# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* FAIL: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

export RM_PANEL=false
export RM_WINGS=false

# --------------- Main functions --------------- #

main() {
  greet ""

  if [ -d "/var/www/pterodactyl" ]; then
    log "Panel installation has been detected."
    echo -e -n "* Do you want to remove panel? (y/N): "
    read -r RM_PANEL_INPUT
    [[ "$RM_PANEL_INPUT" =~ [Yy] ]] && RM_PANEL=true
  fi

  if [ -d "/etc/pterodactyl" ]; then
    log "Wings installation has been detected."
    alert "This will remove all the servers!"
    echo -e -n "* Do you want to remove Wings (daemon)? (y/N): "
    read -r RM_WINGS_INPUT
    [[ "$RM_WINGS_INPUT" =~ [Yy] ]] && RM_WINGS=true
  fi

  if [ "$RM_PANEL" == false ] && [ "$RM_WINGS" == false ]; then
    fail "Nothing to uninstall!"
    exit 1
  fi

  overview

  # confirm uninstallation
  echo -e -n "* Continue with uninstallation? (y/N): "
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    execute_installer "uninstall"
  else
    fail "Uninstallation aborted."
    exit 1
  fi
}

overview() {
  generate_brake 30
  log "Uninstall panel? $RM_PANEL"
  log "Uninstall wings? $RM_WINGS"
  generate_brake 30
}

goodbye() {
  generate_brake 62
  [ "$RM_PANEL" == true ] && log "Panel uninstallation completed"
  [ "$RM_WINGS" == true ] && log "Wings uninstallation completed"
  log "Thank you for using this script."
  generate_brake 62
}

main
goodbye
