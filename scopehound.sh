#!/bin/bash

# --- ScopeHound ---
# A simple, clean recon chain script.

# 1. Define Colors
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m" # No Color

# 2. Check for input
if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <domain.com>${NC}"
    exit 1
fi

TARGET=$1
# Create a directory for this target's results
mkdir -p "$TARGET"
cd "$TARGET"

# --- Step 1: Subdomain Enumeration ---
echo -e "${BLUE}[*] Gathering subdomains for $TARGET...${NC}"
# Run tools and send their noisy output to /dev/null
subfinder -d $TARGET -silent -o subfinder.txt > /dev/null 2>&1
assetfinder --subs-only $TARGET > assetfinder.txt 2> /dev/null
findomain -t $TARGET -q > findomain.txt
# amass is very powerful but slower, uncomment if you want it
# amass enum -d $TARGET -silent -o amass.txt > /dev/null 2>&1

echo -e "${GREEN}[+] Subdomain gathering complete.${NC}"

# --- Step 2: Combine & Uniq ---
echo -e "${BLUE}[*] Combining and sorting unique subdomains...${NC}"
# Combine all results and find unique entries
cat subfinder.txt assetfinder.txt findomain.txt | sort -u > all_subdomains.txt

COUNT=$(wc -l < all_subdomains.txt)
echo -e "${GREEN}[+] Found ${YELLOW}$COUNT${GREEN} unique subdomains.${NC}"

# --- Step 3: Port Scan ---
echo -e "${BLUE}[*] Running fast port scan (Top 100) on subdomains...${NC}"
# We use naabu for this. It's fast and designed for this workflow.
# -silent hides the banner, and we dev/null the rest.
naabu -list all_subdomains.txt -top-ports 100 -silent -o open_ports.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Port scan complete.${NC}"

# --- Step 4: Find Live Web Servers ---
echo -e "${BLUE}[*] Probing for live web servers...${NC}"
# Feed the host:port combinations from naabu into httpx
# -silent hides the httpx banner
cat open_ports.txt | httpx -silent -o live_web_servers.txt
echo -e "${GREEN}[+] HTTP probing complete.${NC}"

# --- Step 5: Clean Output ---
echo -e "\n${YELLOW}--- Live Web Servers Found for $TARGET ---${NC}"
if [ -s live_web_servers.txt ]; then
    # The final, clean output
    cat live_web_servers.txt
else
    echo -e "${RED}No live web servers found.${NC}"
fi

# The results are saved in the $TARGET/ directory
cd ..
