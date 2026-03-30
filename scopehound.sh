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
cd "$TARGET" || exit

# --- Step 1: Subdomain Enumeration ---
echo -e "${BLUE}[*] Gathering Subdomains For $TARGET...${NC}"
# Fix: Corrected redirection to avoid truncating files
subfinder -d "$TARGET" -silent -o subfinder.txt > /dev/null 2>&1
assetfinder --subs-only "$TARGET" > assetfinder.txt 2>/dev/null
findomain -t "$TARGET" -q > findomain.txt 2>/dev/null

echo -e "${GREEN}[+] Subdomain gathering complete.${NC}"

# --- Step 2: Combine & Uniq ---
echo -e "${BLUE}[*] Combining And Sorting Unique Subdomains...${NC}"
# Fix: Removed the trailing /dev/null which was breaking the sort output
sort -u subfinder.txt assetfinder.txt findomain.txt > all_subdomains.txt

COUNT=$(wc -l < all_subdomains.txt)
echo -e "${GREEN}[+] Found ${YELLOW}$COUNT${GREEN} Unique Subdomains.${NC}"

# --- Step 3: Port Scan ---
echo -e "${BLUE}[*] Running Fast Port Scan (Top 100) On Subdomains...${NC}"
# Use -o for output and 2>/dev/null to hide errors/banners
naabu -list all_subdomains.txt -top-ports 100 -silent -o open_ports.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Port Scan Complete...${NC}"

# --- Step 4: Find Live Web Servers ---
echo -e "${BLUE}[*] Probing For Live Web Servers...${NC}"
# Fix: Use -o instead of tee if you are sending stdout to /dev/null anyway
httpx -l open_ports.txt -silent -o alive_subs.txt > /dev/null 2>&1
echo -e "${GREEN}[+] HTTP Probing Complete...${NC}"

# --- Step 5: Clean Output ---
echo -e "\n${YELLOW}--- Live Web Servers Found for $TARGET ---${NC}"
cat alive_subs.txt

# --- Step 6: Scanning For Historical Data With GAU  ---
echo -e "${BLUE}[*] Scanning Historical Sources With GAU...${NC}"
gau --subs "$TARGET" > gau.txt 2>/dev/null
echo -e "${GREEN}[+] GAU Scanning Complete.${NC}"

# --- Step 7: Downloading Javascript files
echo -e "${BLUE}[*] Crawling For Javascript Files...${NC}"
# Fix: Katana -jc (js-crawl) is heavy; using -o for clean saving
katana -list alive_subs.txt -jc -d 2 -silent -o alive_subs_js_files.txt > /dev/null 2>&1
# Optional: Filter gau.txt for JS specifically before running katana to save time
grep "\.js" gau.txt | katana -silent -o gau_js_files.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Javascript Files Logged...${NC}"

# --- Step 8: Hunting For Vulnerabilities With Nuclei
echo -e "${BLUE}[*] Hunting For Vulnerabilities With Nuclei ${NC}"
# Fix: Ensure templates are updated and path is correct
nuclei -l alive_subs.txt -t ~/nuclei-templates -silent -o nuclei.txt > /dev/null 2>&1
echo -e "${GREEN}[+] Vulnerability Scanning Complete...${NC}"

# --- Recon Completed 
echo -e "${GREEN}[+] Recon Completed. Results saved in $(pwd)${NC}"

cd ..
