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
# Define the absolute path for the results to prevent directory scoping issues
RESULTS_DIR="$(pwd)/$TARGET"

# Create the target directory
mkdir -p "$RESULTS_DIR"

# --- Step 1: Subdomain Enumeration ---
echo -e "${BLUE}[*] Gathering Subdomains For $TARGET...${NC}"
# Redirecting stderr to /dev/null to keep the terminal clean
subfinder -d "$TARGET" -silent -o "$RESULTS_DIR/subfinder.txt" > /dev/null 2>&1
assetfinder --subs-only "$TARGET" > "$RESULTS_DIR/assetfinder.txt" 2>/dev/null
findomain -t "$TARGET" -q > "$RESULTS_DIR/findomain.txt" 2>/dev/null

echo -e "${GREEN}[+] Subdomain gathering complete.${NC}"

# --- Step 2: Combine & Uniq ---
echo -e "${BLUE}[*] Combining And Sorting Unique Subdomains...${NC}"
# Combine results into the results directory
sort -u "$RESULTS_DIR/subfinder.txt" "$RESULTS_DIR/assetfinder.txt" "$RESULTS_DIR/findomain.txt" > "$RESULTS_DIR/all_subdomains.txt"

COUNT=$(wc -l < "$RESULTS_DIR/all_subdomains.txt")
echo -e "${GREEN}[+] Found ${YELLOW}$COUNT${GREEN} Unique Subdomains.${NC}"

# --- Step 3: Find Live Web Servers (Direct Probing) ---
echo -e "${BLUE}[*] Probing For Live Web Servers...${NC}"
# We probe all_subdomains directly to ensure we don't miss anything
httpx -l "$RESULTS_DIR/all_subdomains.txt" -silent -o "$RESULTS_DIR/alive_subs.txt" > /dev/null 2>&1

ALIVE_COUNT=$(wc -l < "$RESULTS_DIR/alive_subs.txt" 2>/dev/null || echo 0)
echo -e "${GREEN}[+] Found ${YELLOW}$ALIVE_COUNT${GREEN} Alive Web Servers.${NC}"

# --- Step 4: Port Scan ---
echo -e "${BLUE}[*] Running Fast Port Scan (Top 100)...${NC}"
naabu -list "$RESULTS_DIR/all_subdomains.txt" -top-ports 100 -silent -o "$RESULTS_DIR/open_ports.txt" > /dev/null 2>&1
echo -e "${GREEN}[+] Port Scan Complete.${NC}"

# --- Only proceed with heavy scanning if alive hosts were found ---
if [ "$ALIVE_COUNT" -gt 0 ]; then

    # --- Step 5: Scanning For Historical Data With GAU ---
    echo -e "${BLUE}[*] Scanning Historical Sources With GAU...${NC}"
    cat "$RESULTS_DIR/alive_subs.txt" | gau --subs > "$RESULTS_DIR/gau.txt" 2>/dev/null
    echo -e "${GREEN}[+] GAU Scanning Complete.${NC}"

    # --- Step 6: Downloading Javascript Files ---
    echo -e "${BLUE}[*] Crawling For Javascript Files...${NC}"
    # Crawl the live subdomains
    katana -list "$RESULTS_DIR/alive_subs.txt" -jc -silent -o "$RESULTS_DIR/alive_subs_js_files.txt" > /dev/null 2>&1
    # Extract JS from GAU results
    grep "\.js" "$RESULTS_DIR/gau.txt" > "$RESULTS_DIR/gau_js_files.txt" 2>/dev/null
    echo -e "${GREEN}[+] Javascript Files Logged.${NC}"

    # --- Step 7: Hunting For Vulnerabilities With Nuclei ---
    echo -e "${BLUE}[*] Hunting For Vulnerabilities With Nuclei...${NC}"
    nuclei -l "$RESULTS_DIR/alive_subs.txt" -t ~/nuclei-templates -silent -o "$RESULTS_DIR/nuclei.txt" > /dev/null 2>&1
    echo -e "${GREEN}[+] Vulnerability Scanning Complete.${NC}"

else
    echo -e "${RED}[!] No alive subdomains found. Skipping GAU, Katana, and Nuclei.${NC}"
fi

# --- Recon Completed 
echo -e "\n${GREEN}[+] Recon Completed for $TARGET!${NC}"
echo -e "${YELLOW}[i] Results are stored in: $RESULTS_DIR${NC}"
