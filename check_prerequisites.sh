#!/bin/bash

# CyberArk HTML5 Gateway Certificate Upgrade Script
# Author: Daniel V
# Date: 25-10-2024
# Version: 0.1

# Paths (Adjust these paths as needed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/certificates"
TOMCAT_DIR="/opt/tomcat"
GUACAMOLE_SSL_DIR="/etc/guacamole/GuaSSL"

# Logs Directory
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/prerequisites_check.log"

# Ensure logs directory exists
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Function: log_message
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function: check_command
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_message "Error: $1 command not found."
        exit 1
    else
        log_message "Found command: $1"
    fi
}

# Function: check_file
check_file() {
    if [ ! -f "$1" ]; then
        log_message "Error: File not found - $1"
        exit 1
    else
        log_message "Found file: $1"
    fi
}

# Function: check_directory
check_directory() {
    if [ ! -d "$1" ]; then
        log_message "Error: Directory not found - $1"
        exit 1
    else
        log_message "Found directory: $1"
    fi
}

# Main Prerequisites Check
log_message "Starting prerequisites check..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_message "This script must be run as root. Use sudo or switch to root user."
    exit 1
fi

# Check required commands
check_command openssl
check_command keytool

# Check directories
check_directory "$CERT_DIR"
check_directory "$TOMCAT_DIR"
check_directory "$GUACAMOLE_SSL_DIR"

# Check PFX file
PFX_FILE="${CERT_DIR}/your_certificate.pfx"
check_file "$PFX_FILE"

# Check server.xml
check_file "${TOMCAT_DIR}/conf/server.xml"

# Check Java cacerts keystore
if [ -f /etc/os-release ]; then
    OS=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
else
    log_message "Cannot detect operating system."
    exit 1
fi

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    JAVA_KEYSTORE_PATH="/usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/cacerts"
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    JAVA_KEYSTORE_PATH="$(readlink -f /usr/bin/java | sed 's:bin/java::')lib/security/cacerts"
else
    log_message "Unsupported operating system: $OS"
    exit 1
fi

check_file "$JAVA_KEYSTORE_PATH"

log_message "All prerequisites are met. You can proceed with running the upgrade script."
