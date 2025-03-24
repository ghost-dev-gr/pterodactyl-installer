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

# ------------------ Force Download lib.sh ----------------- #
export GITHUB_BASE_URL="https://raw.githubusercontent.com/ghost-dev-gr/pterodactyl-installer"
export GITHUB_SOURCE="v1.1.1"
export SCRIPT_RELEASE="v1.1.1"

# Function to forcefully download lib.sh
force_download_lib() {
    echo "=> Ensuring /tmp directory exists..."
    mkdir -p /tmp
    
    echo "=> Removing any existing lib.sh..."
    rm -f /tmp/lib.sh
    
    echo "=> Attempting to download lib.sh..."
    
    # Try multiple download methods and sources
    declare -a download_urls=(
        "$GITHUB_BASE_URL/master/lib/lib.sh"
        "$GITHUB_BASE_URL/$GITHUB_SOURCE/lib/lib.sh"
        "https://cdn.jsdelivr.net/gh/ghost-dev-gr/pterodactyl-installer@master/lib/lib.sh"
    )
    
    for url in "${download_urls[@]}"; do
        echo "==> Trying $url"
        if curl -sSL -o /tmp/lib.sh "$url" || wget -q -O /tmp/lib.sh "$url"; then
            if [ -s "/tmp/lib.sh" ]; then
                echo "=> Successfully downloaded lib.sh from $url"
                return 0
            fi
            echo "==> Downloaded empty file, trying next source..."
        else
            echo "==> Download failed, trying next source..."
        fi
        sleep 1
    done
    
    echo "ERROR: All download attempts failed!"
    exit 1
}

# Function to check if a function exists
fn_exists() { declare -F "$1" >/dev/null; }

# ------------------ Load lib.sh ----------------- #
if ! fn_exists lib_loaded; then
    force_download_lib
    
    # Verify the download
    if [ ! -f "/tmp/lib.sh" ] || [ ! -s "/tmp/lib.sh" ]; then
        echo "ERROR: Downloaded lib.sh is empty or missing!"
        exit 1
    fi
    
    # shellcheck source=/tmp/lib.sh
    source /tmp/lib.sh || { echo "ERROR: Failed to load lib.sh"; exit 1; }
    
    # Verify lib.sh was properly loaded
    if ! fn_exists lib_loaded; then
        echo "ERROR: lib.sh did not load correctly"
        exit 1
    fi
fi

# ------------------ Variables ----------------- #
INSTALL_MARIADB="${INSTALL_MARIADB:-false}"

# firewall
CONFIGURE_FIREWALL="${CONFIGURE_FIREWALL:-false}"

# SSL (Let's Encrypt)
CONFIGURE_LETSENCRYPT="${CONFIGURE_LETSENCRYPT:-false}"
FQDN="${FQDN:-}"
EMAIL="${EMAIL:-}"

# Database host
CONFIGURE_DBHOST="${CONFIGURE_DBHOST:-false}"
CONFIGURE_DB_FIREWALL="${CONFIGURE_DB_FIREWALL:-false}"
MYSQL_DBHOST_HOST="${MYSQL_DBHOST_HOST:-127.0.0.1}"
MYSQL_DBHOST_USER="${MYSQL_DBHOST_USER:-pterodactyluser}"
MYSQL_DBHOST_PASSWORD="${MYSQL_DBHOST_PASSWORD:-}"

if [[ $CONFIGURE_DBHOST == true && -z "${MYSQL_DBHOST_PASSWORD}" ]]; then
  error "Mysql database host user password is required"
  exit 1
fi

# ----------- Installation functions ----------- #

enable_services() {
  [ "$INSTALL_MARIADB" == true ] && systemctl enable mariadb
  [ "$INSTALL_MARIADB" == true ] && systemctl start mariadb
  systemctl start docker
  systemctl enable docker
}

dep_install() {
  output "Installing dependencies for $OS $OS_VER..."

  [ "$CONFIGURE_FIREWALL" == true ] && install_firewall && firewall_ports

  case "$OS" in
  ubuntu | debian)
    install_packages "ca-certificates gnupg lsb-release"

    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    ;;

  rocky | almalinux)
    install_packages "dnf-utils"
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

    [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "epel-release"

    install_packages "device-mapper-persistent-data lvm2"
    ;;
  esac

  # Update the new repos
  update_repos

  # Install dependencies
  install_packages "docker-ce docker-ce-cli containerd.io"

  # Install mariadb if needed
  [ "$INSTALL_MARIADB" == true ] && install_packages "mariadb-server"
  [ "$CONFIGURE_LETSENCRYPT" == true ] && install_packages "certbot"

  enable_services

  success "Dependencies installed!"
}

ptdl_dl() {
  output "Downloading custom wings files..."
  
  # Create wings directory
  WINGSDIR="/usr/local/bin/wings"
  mkdir -p "$WINGSDIR"
  cd "$WINGSDIR" || exit

  rm -rf wings wings-* wings.zip wings.tar.gz 2>/dev/null

  # Define URLs
  ZIP_URL="https://github.com/ghost-dev-gr/wings/releases/latest/download/wings.zip"
  TAR_URL="https://github.com/ghost-dev-gr/wings/releases/latest/download/wings.tar.gz"
  GIT_URL="https://github.com/ghost-dev-gr/wings.git"

  # Function to validate downloaded file
  validate_file() {
    local file=$1
    echo "Validating $file..."
    
    if [ ! -s "$file" ]; then
      echo "Error: File is empty or doesn't exist"
      return 1
    fi

    file_type=$(file -b "$file")
    echo "File type: $file_type"

    if [[ "$file_type" == *"Zip archive"* ]] || 
       [[ "$file_type" == *"gzip compressed"* ]] || 
       [[ "$file_type" == *"tar archive"* ]]; then
      return 0
    fi

    if head -1 "$file" | grep -qi "html\|404\|not found\|error"; then
      echo "Error: Downloaded file appears to be an error page"
      return 1
    fi

    return 0
  }

  # Attempt download methods
  download_attempt() {
    echo "Attempting download method: $1"
    
    case $1 in
      curl_zip)
        curl -L -o wings.zip "$ZIP_URL" || return 1
        validate_file "wings.zip" || return 1
        unzip -o wings.zip -d "$WINGSDIR" && rm -f wings.zip
        ;;
      wget_zip)
        wget -O wings.zip "$ZIP_URL" || return 1
        validate_file "wings.zip" || return 1
        unzip -o wings.zip -d "$WINGSDIR" && rm -f wings.zip
        ;;
      curl_tar)
        curl -L -o wings.tar.gz "$TAR_URL" || return 1
        validate_file "wings.tar.gz" || return 1
        tar -xzf wings.tar.gz -C "$WINGSDIR" && rm -f wings.tar.gz
        ;;
      wget_tar)
        wget -O wings.tar.gz "$TAR_URL" || return 1
        validate_file "wings.tar.gz" || return 1
        tar -xzf wings.tar.gz -C "$WINGSDIR" && rm -f wings.tar.gz
        ;;
      git_clone)
        git clone --depth 1 --branch "$TAG" "$GIT_URL" wings || return 1
        ;;
      *)
        return 1
        ;;
    esac
    
    return 0
  }

  # Try download methods in sequence
  for method in curl_zip wget_zip curl_tar wget_tar git_clone; do
    if download_attempt "$method"; then
      # Move the directory if the downloaded content is inside another folder like "wings-$TAG"
      if [ -d "wings-$TAG" ]; then
        mv "wings-$TAG" wings
      fi
      
      if [ -d "wings" ]; then
        success "Successfully downloaded wings files using $method"
        break
      fi
    fi
    echo "Download method $method failed, trying next..."
    sleep 2
  done

  # Set execute permissions
  chmod -R u+x "$WINGSDIR"

  # Download the binary for Wings
  mkdir -p /etc/pterodactyl
  curl -L -o /usr/local/bin/wings "$WINGS_DL_BASE_URL$ARCH"
  chmod u+x /usr/local/bin/wings

  success "Pterodactyl Wings downloaded successfully"
}

install_golang() {
  output "Installing Go 1.22.1..."
  wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz -O /tmp/go.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
  source /etc/profile
}

systemd_file() {
  output "Installing systemd service.."

  curl -o /etc/systemd/system/wings.service "$GITHUB_URL"/configs/wings.service
  systemctl daemon-reload
  systemctl enable wings

  success "Installed systemd service!"
}

firewall_ports() {
  output "Opening port 22 (SSH), 8080 (Wings Port), 2022 (Wings SFTP Port)"

  [ "$CONFIGURE_LETSENCRYPT" == true ] && firewall_allow_ports "80 443"
  [ "$CONFIGURE_DB_FIREWALL" == true ] && firewall_allow_ports "3306"

  firewall_allow_ports "22"
  output "Allowed port 22"
  firewall_allow_ports "8080"
  output "Allowed port 8080"
  firewall_allow_ports "2022"
  output "Allowed port 2022"

  success "Firewall ports opened!"
}

letsencrypt() {
  FAILED=false

  output "Configuring LetsEncrypt.."

  # If user has nginx
  systemctl stop nginx || true

  # Obtain certificate
  certbot certonly --no-eff-email --email "$EMAIL" --standalone -d "$FQDN" || FAILED=true

  systemctl start nginx || true

  # Check if it succeded
  if [ ! -d "/etc/letsencrypt/live/$FQDN/" ] || [ "$FAILED" == true ]; then
    warning "The process of obtaining a Let's Encrypt certificate failed!"
  else
    success "The process of obtaining a Let's Encrypt certificate succeeded!"
  fi
}

configure_mysql() {
  output "Configuring MySQL.."

  create_db_user "$MYSQL_DBHOST_USER" "$MYSQL_DBHOST_PASSWORD" "$MYSQL_DBHOST_HOST"
  grant_all_privileges "*" "$MYSQL_DBHOST_USER" "$MYSQL_DBHOST_HOST"

  if [ "$MYSQL_DBHOST_HOST" != "127.0.0.1" ]; then
    echo "* Changing MySQL bind address.."

    case "$OS" in
    debian | ubuntu)
      sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
      ;;
    rocky | almalinux)
      sed -ne 's/^#bind-address=0.0.0.0$/bind-address=0.0.0.0/' /etc/my.cnf.d/mariadb-server.cnf
      ;;
    esac

    systemctl restart mysqld
  fi

  success "MySQL configured!"
}

# --------------- Main functions --------------- #

perform_install() {
  output "Installing pterodactyl wings.."
  dep_install
  install_golang
  ptdl_dl
  systemd_file
  [ "$CONFIGURE_DBHOST" == true ] && configure_mysql
  [ "$CONFIGURE_LETSENCRYPT" == true ] && letsencrypt

 # Create server_certs directory
  mkdir -p /srv/server_certs
  chmod 700 /srv/server_certs
  return 0
}

# ---------------- Installation ---------------- #

perform_install