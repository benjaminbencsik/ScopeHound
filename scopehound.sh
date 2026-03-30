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
echo -e "${BLUE}[*] Gathering Subdomains For $TARGET...${NC}"
# Run subdomain discovery while silencing output to /dev/null
subfinder -d $TARGET -silent -o subfinder.txt > /dev/null 2>&1
assetfinder --subs-only $TARGET > assetfinder.txt > /dev/null 2>&1
findomain -t $TARGET -q > findomain.txt > /dev/null 2>&1


echo -e "${GREEN}[+] Subdomain gathering complete.${NC}"

# --- Step 2: Combine & Uniq ---
echo -e "${BLUE}[*] Combining And Sorting Unique Subdomains...${NC}"
# Combine all results and find unique entries
cat subfinder.txt assetfinder.txt findomain.txt | sort -u > all_subdomains.txt /dev/null 2>&1

COUNT=$(wc -l < all_subdomains.txt)
echo -e "${GREEN}[+] Found ${YELLOW}$COUNT${GREEN} Unique Subdomains.${NC}"

# --- Step 3: Port Scan ---
echo -e "${BLUE}[*] Running Fast Port Scan (Top 100) On Subdomains...${NC}"
# We use naabu for this. It's fast and designed for this workflow.
# -silent hides the banner, and we dev/null the rest.
naabu -list all_subdomains.txt -top-ports 100 -silent -o open_ports.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Port Scan Complete...${NC}"

# --- Step 4: Find Live Web Servers ---
echo -e "${BLUE}[*] Probing For Live Web Servers...${NC}"
# Feed the host:port combinations from naabu into httpx
# -silent hides the httpx banner
cat open_ports.txt | httpx -silent | tee alive_subs.txt > /dev/null 2>&1
echo -e "${GREEN}[+] HTTP Probing Complete...${NC}"

# --- Step 5: Clean Output ---
echo -e "\n${YELLOW}--- Live Web Servers Found for $TARGET ---${NC}"

# --- Step 6: Scanning For Historical Data With GAU  ---
echo -e "${BLUE}[*] Scanning Historical Sources With GAU...${NC}"
# Feed alive subdomains through GAU 
cat alive_subs.txt | gau | tee gau.txt > /dev/null 2>&1
echo -e "${GREEN}[+] GAU Scanning Complete.${NC}"

# --- Step 7: Downloading Javascript files from alive subdomains and historical data
echo -e "${BLUE}[*] Downloading Javascript Files From Alive Subdomains And Historical Data...${NC}"
# Downloading javascript files on alive_subs.txt with katana first 
cat alive_subs.txt | katana -jc | tee alive_subs_js_files.txt > /dev/null 2>&1
cat gau.txt | katana -jc | tee gau_js_files.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Javascript Files Downloaded...${NC}"


# --- Step 8: Hunting For Vulnerabilities With Nuclei
echo -e "${BLUE}[*] Hunting For Vulnerabilities With Nuclei ${NC}"
cat alive_subs.txt | nuclei -t ~/nuclei-templates | tee nuclei.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Vulnerability Scanning Complete...${NC}"


# --- Recon Completed 
echo -e "${GREEN}[+] Recon Completed...${NC}"


# The results are saved in the $TARGET/ directory
cd ..
