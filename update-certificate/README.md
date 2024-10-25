# CyberArk HTML5 Gateway Certificate Upgrade Script

## Overview

This script automates the process of upgrading the SSL certificate for the CyberArk HTML5 Gateway. It extracts the necessary certificate and key from a PFX file, updates the Tomcat keystore, updates Guacamole SSL certificates, and restarts the necessary services.

## Prerequisites

### 1. System Requirements

- **Operating System**: Linux-based system (Ubuntu/Debian or CentOS/RHEL/Fedora) where CyberArk HTML5 Gateway is installed.
- **User Permissions**: Must be run as the root user or with `sudo` privileges.

### 2. Software Dependencies

- **OpenSSL**
- **Keytool**
- **Java JDK/JRE**

### 3. Files and Directories

- **Script Files**
  - `upgrade_certificate.sh`: The main bash script.
  - `check_prerequisites.sh`: Script to check prerequisites.
- **Certificates Directory**
  - `/certificates`: Place your new PFX certificate file here.
- **Logs Directory**
  - `/logs`: The scripts will output logs to this directory.
- **PFX Certificate File**
  - Place your PFX file (e.g., `your_certificate.pfx`) inside the `/certificates` directory.

### 4. Configuration Variables

Before running the scripts, adjust the configuration variables at the top of each script as needed.

- **Paths**
  - `SCRIPT_DIR`: The directory where the scripts are located (automatically determined).
  - `CERT_DIR`: Path to the `/certificates` directory (relative to `SCRIPT_DIR`).
  - `TOMCAT_DIR`: Path to the Tomcat installation directory.
  - `GUACAMOLE_SSL_DIR`: Path to the Guacamole SSL directory.
  - `JAVA_KEYSTORE_PATH`: Path to the Java `cacerts` keystore (automatically detected).
  - `LOG_DIR`: Path to the `/logs` directory (relative to `SCRIPT_DIR`).
  - `LOG_FILE`: Path to the log file inside `LOG_DIR`.
- **Filenames**
  - `PFX_FILE`: Full path to your PFX certificate file.
  - `KEYSTORE_FILE`: Path to the Tomcat keystore file.
- **Passwords**
  - `PFX_PASSWORD`: Password for the PFX file (leave empty to be prompted).
  - `KEYSTORE_PASSWORD`: Password for the Tomcat keystore (leave empty to be prompted).
  - `CACERTS_PASSWORD`: Password for the Java `cacerts` keystore (default is `changeit`).

## Usage Instructions

### 1. Preparation

- Place the `upgrade_certificate.sh` and `check_prerequisites.sh` scripts and `README.md` in your chosen directory.
- Create the `/certificates` subdirectory in the same directory as the scripts.
- Place the new PFX certificate file inside the `/certificates` subdirectory.
- Modify the scripts' configuration variables to match your environment if necessary.

### 2. Run Prerequisites Script

- Make the script executable:

  ```bash
  chmod +x check_prerequisites.sh
