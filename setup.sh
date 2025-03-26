#!/bin/bash

set -e

# Read dynamic path
PATH_FILE="Codebase/Config/path.txt"
if [ ! -f "$PATH_FILE" ]; then
    echo "path.txt not found at $PATH_FILE"
    exit 1
fi

PROJECT_ROOT=$(cat "$PATH_FILE" | sed 's:/*$::')
INSTALL_SCRIPT="$PROJECT_ROOT/Codebase/Deploy/install-nginx.sh"
NGINX_BIN="$PROJECT_ROOT/nginx/sbin/nginx"
LOG_DIR="$PROJECT_ROOT/logs"
GEN_NGINX="$PROJECT_ROOT/Codebase/Deploy/generate-nginx-conf.sh"
GEN_SITES="$PROJECT_ROOT/Codebase/Deploy/generate-sites.sh"
CERTBOT_SCRIPT="$PROJECT_ROOT/Codebase/Deploy/install-certbot.sh"
CHECK_CERTS_SCRIPT="$PROJECT_ROOT/Codebase/Deploy/check-certs.sh"

echo ""
echo "Starting full setup from: $PROJECT_ROOT"

# Ensure logs directory exists
echo "Ensuring log directory exists at: $LOG_DIR"
mkdir -p "$LOG_DIR"

# Install Nginx if missing
if [ ! -f "$NGINX_BIN" ]; then
    echo ""
    echo "Nginx binary not found — running installer..."
    bash "$INSTALL_SCRIPT"
else
    echo ""
    echo "Nginx already installed at: $NGINX_BIN"
fi

# Confirm Nginx installed
if [ ! -x "$NGINX_BIN" ]; then
    echo "Nginx installation failed or binary not executable."
    exit 1
fi

# Generate configs
echo ""
echo "Generating dynamic configs..."
bash "$GEN_NGINX"
bash "$GEN_SITES"

# Install Certbot system-wide
echo ""
echo "Installing Certbot..."
bash "$CERTBOT_SCRIPT"


echo ""
echo "Ensuring daily Certbot renewal cronjob exists..."

# Check if job exists already
( crontab -l 2>/dev/null | grep -F "$CRON_JOB" ) >/dev/null
if [ $? -ne 0 ]; then
    echo "Adding daily cert renewal job to crontab..."
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
else
    echo "Cronjob for cert renewal already exists."
fi

# Run cert check immediately after setup
echo ""
echo "Running initial certificate check/renewal..."
bash "$CHECK_CERTS_SCRIPT"