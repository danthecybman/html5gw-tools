#!/bin/bash

# CyberArk HTML5 Gateway Certificate Upgrade Script
# Author: Daniel V
# Date: 25-10-2024
# Version: 0.1


######################
# Configuration Variables
######################

# Operating System Detection
OS=""
if [ -f /etc/os-release ]; then
    OS=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
else
    echo "Cannot detect operating system."
    exit 1
fi

# Paths (Adjust these paths as needed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/certificates"
TOMCAT_DIR="/opt/tomcat"
GUACAMOLE_SSL_DIR="/etc/guacamole/GuaSSL"

# Logs Directory
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/certificate_upgrade.log"

# Ensure logs directory exists
mkdir -p "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Java Keystore Path (Adjust based on OS)
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    JAVA_KEYSTORE_PATH="/usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/cacerts"
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    JAVA_KEYSTORE_PATH="$(readlink -f /usr/bin/java | sed 's:bin/java::')lib/security/cacerts"
else
    echo "Unsupported operating system: $OS"
    exit 1
fi

# Filenames
PFX_FILE="${CERT_DIR}/your_certificate.pfx"
KEYSTORE_FILE="${TOMCAT_DIR}/keystore"

# Passwords (Leave empty to prompt during execution)
PFX_PASSWORD=""
KEYSTORE_PASSWORD=""
CACERTS_PASSWORD="changeit"  # Default Java keystore password

######################
# Function Definitions
######################

# Function: log_message
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function: check_requirements
check_requirements() {
    # Verify script is run as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root. Use sudo or switch to root user."
        exit 1
    fi

    # Check for required commands
    for cmd in openssl keytool; do
        if ! command -v $cmd &> /dev/null; then
            log_message "Error: $cmd command not found."
            exit 1
        fi
    done

    # Confirm files and directories exist
    if [ ! -d "$CERT_DIR" ]; then
        log_message "Error: Certificates directory not found at $CERT_DIR."
        exit 1
    fi

    if [ ! -f "$PFX_FILE" ]; then
        log_message "Error: PFX file not found at $PFX_FILE."
        exit 1
    fi

    if [ ! -d "$TOMCAT_DIR" ]; then
        log_message "Error: Tomcat directory not found at $TOMCAT_DIR."
        exit 1
    fi

    if [ ! -d "$GUACAMOLE_SSL_DIR" ]; then
        log_message "Error: Guacamole SSL directory not found at $GUACAMOLE_SSL_DIR."
        exit 1
    fi

    if [ ! -f "$JAVA_KEYSTORE_PATH" ]; then
        log_message "Error: Java cacerts keystore not found at $JAVA_KEYSTORE_PATH."
        exit 1
    fi
}

# Function: get_passwords
get_passwords() {
    # Get PFX password
    if [ -z "$PFX_PASSWORD" ]; then
        read -s -p "Enter the password for the PFX file: " PFX_PASSWORD
        echo
    fi

    # Get keystore password from server.xml or prompt
    if [ -z "$KEYSTORE_PASSWORD" ]; then
        if [ -f "${TOMCAT_DIR}/conf/server.xml" ]; then
            KEYSTORE_PASSWORD=$(grep 'keystorePass' "${TOMCAT_DIR}/conf/server.xml" | sed 's/.*keystorePass="\([^"]*\)".*/\1/')
        fi

        if [ -z "$KEYSTORE_PASSWORD" ]; then
            read -s -p "Enter the keystore password (found in server.xml): " KEYSTORE_PASSWORD
            echo
        fi
    fi

    # Confirm whether to use the default cacerts password
    if [ "$CACERTS_PASSWORD" == "changeit" ]; then
        read -p "Use default Java cacerts password 'changeit'? [Y/n]: " use_default_cacerts
        if [[ "$use_default_cacerts" =~ ^[Nn]$ ]]; then
            read -s -p "Enter the Java cacerts keystore password: " CACERTS_PASSWORD
            echo
        fi
    fi
}

# Function: confirm_certificate
confirm_certificate() {
    # Display certificate details
    CERT_DETAILS=$(openssl pkcs12 -in "$PFX_FILE" -info -nodes -passin pass:"$PFX_PASSWORD" 2>/dev/null | openssl x509 -noout -subject -dates)
    if [ -z "$CERT_DETAILS" ]; then
        log_message "Error: Unable to read certificate details. Check the PFX password."
        exit 1
    fi

    echo "Certificate Details:"
    echo "$CERT_DETAILS"
    echo
    read -p "Proceed with using this certificate? [Y/n]: " proceed
    if [[ "$proceed" =~ ^[Nn]$ ]]; then
        log_message "Certificate upgrade cancelled by user."
        exit 0
    fi
}

# Function: backup_files
backup_files() {
    log_message "Backing up existing certificates and keystores..."
    TIMESTAMP=$(date '+%Y%m%d%H%M%S')

    # Backup Tomcat certificates and keystore
    cd "$TOMCAT_DIR"
    for file in cert.crt server.key keystore; do
        if [ -f "$file" ]; then
            mv "$file" "${file}.bak_$TIMESTAMP"
        fi
    done

    # Backup Guacamole certificates
    cd "$GUACAMOLE_SSL_DIR"
    for file in cert.crt cert.pem key.pem server.key; do
        if [ -f "$file" ]; then
            mv "$file" "${file}.bak_$TIMESTAMP"
        fi
    done
}

# Function: extract_certificate_and_key
extract_certificate_and_key() {
    log_message "Extracting private key from PFX..."
    cd "$CERT_DIR"
    openssl pkcs12 -in "$PFX_FILE" -nocerts -out key.pem -passin pass:"$PFX_PASSWORD" -passout pass:"$PFX_PASSWORD"
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to extract private key."
        exit 1
    fi

    log_message "Extracting certificate from PFX..."
    openssl pkcs12 -in "$PFX_FILE" -clcerts -nokeys -out cert.pem -passin pass:"$PFX_PASSWORD"
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to extract certificate."
        exit 1
    fi
}

# Function: convert_certificates
convert_certificates() {
    log_message "Converting PEM certificate to DER format..."
    openssl x509 -outform der -in cert.pem -out cert.crt
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to convert certificate."
        exit 1
    fi

    log_message "Converting private key to RSA format..."
    openssl rsa -in key.pem -out server.key -passin pass:"$PFX_PASSWORD"
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to convert private key."
        exit 1
    fi

    chmod 644 cert.crt cert.pem key.pem server.key
}

# Function: import_into_keystore
import_into_keystore() {
    log_message "Importing PFX into Tomcat keystore..."
    cd "$TOMCAT_DIR"
    keytool -importkeystore -srckeystore "$PFX_FILE" -srcstoretype pkcs12 -srcstorepass "$PFX_PASSWORD" \
    -destkeystore keystore -deststoretype JKS -deststorepass "$KEYSTORE_PASSWORD" -noprompt
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to import keystore."
        exit 1
    fi

    chown tomcat:tomcat keystore
    chmod 644 keystore
}

# Function: update_guacamole_certificates
update_guacamole_certificates() {
    log_message "Updating Guacamole SSL certificates..."
    cd "$GUACAMOLE_SSL_DIR"

    cp "${CERT_DIR}/cert.crt" .
    cp "${CERT_DIR}/cert.pem" .
    cp "${CERT_DIR}/key.pem" .
    cp "${CERT_DIR}/server.key" .

    chown root:psmgwuser cert.crt cert.pem key.pem server.key
    chmod 644 cert.crt cert.pem key.pem server.key
}

# Function: import_into_cacerts
import_into_cacerts() {
    log_message "Importing certificate into Java cacerts truststore..."
    # Remove old certificate if it exists
    keytool -delete -alias webapp_guacd_cert -keystore "$JAVA_KEYSTORE_PATH" -storepass "$CACERTS_PASSWORD" &> /dev/null

    # Import new certificate
    cd "$CERT_DIR"
    keytool -import -alias webapp_guacd_cert -keystore "$JAVA_KEYSTORE_PATH" -storepass "$CACERTS_PASSWORD" \
    -trustcacerts -file cert.crt -noprompt
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to import certificate into cacerts."
        exit 1
    fi
}

# Function: restart_services
restart_services() {
    log_message "Restarting Tomcat and Guacamole services..."
    systemctl restart tomcat
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to restart Tomcat service."
        exit 1
    fi

    systemctl restart guacd
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to restart Guacamole service."
        exit 1
    fi
}

# Function: cleanup
cleanup() {
    log_message "Cleaning up temporary files..."
    rm -f "${CERT_DIR}/cert.pem" "${CERT_DIR}/key.pem" "${CERT_DIR}/cert.crt" "${CERT_DIR}/server.key"
    log_message "Certificate upgrade process completed successfully."
    echo "Please verify the HTML5 Gateway functionality."
}

# Function: main
main() {
    check_requirements
    get_passwords
    confirm_certificate
    backup_files
    extract_certificate_and_key
    convert_certificates
    import_into_keystore
    update_guacamole_certificates
    import_into_cacerts
    restart_services
    cleanup
}

# Execute main function
main
