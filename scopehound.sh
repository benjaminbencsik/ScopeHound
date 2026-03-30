#!/bin/bash

# Script for improved error handling, input validation, tool checking, and logging

LOGFILE="/tmp/scopehound.log"

# Function to log messages
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Check for required tools and install if not present
check_tool() {
    command -v "$1" >/dev/null 2>&1 || {
        echo -e "\033[31m$1 not found! Installing...\033[0m"
        log "$1 not found! Installing..."
        # Command to install tool (example for apt)
        sudo apt-get install -y "$1" || { 
            echo -e "\033[31mFailed to install $1!\033[0m"
            log "Failed to install $1!"
            exit 1
        }
    }
}

# Input validation for domain
validate_domain() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo -e "\033[31mInvalid domain: $1\033[0m"
        log "Invalid domain: $1"
        exit 1
    fi
}

# Ensure temp directory exists
TMPDIR="/tmp/scopehound"
mkdir -p "$TMPDIR" || {
    echo -e "\033[31mFailed to create temporary directory!\033[0m"
    log "Failed to create temporary directory!"
    exit 1
}

# Prevent race conditions with lock files
LOCKFILE="/tmp/scopehound.lock"
exec 200>$LOCKFILE
flock -n 200 || {
    echo -e "\033[31mScript already running!\033[0m"
    log "Script already running!"
    exit 1
}

# Check for necessary tools
check_tool "curl"
check_tool "jq"

# Usage message
if [ "$#" -ne 1 ]; then
    echo -e "\033[33mUsage: $0 <domain>\033[0m"
    log "Usage error"
    exit 1
fi

DOMAIN="$1"
validate_domain "$DOMAIN"

# Main script logic goes here

# Clean up
rm -rf "$TMPDIR" || {
    echo -e "\033[31mFailed to remove temporary directory!\033[0m"
    log "Failed to remove temporary directory!"
    exit 1
}

log "Script completed successfully."