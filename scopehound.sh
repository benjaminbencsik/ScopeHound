#!/bin/bash

# --- ScopeHound ---
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <domain.com>${NC}"
    exit 1
fi

TARGET=$1
RESULTS_DIR="$(pwd)/$TARGET"
mkdir -p "$RESULTS_DIR/gf_patterns"

# --- Step 1: Subdomain Enumeration ---
echo -e "${BLUE}[*] Gathering Subdomains...${NC}"
subfinder -d "$TARGET" -silent -o "$RESULTS_DIR/subfinder.txt" > /dev/null 2>&1
assetfinder --subs-only "$TARGET" > "$RESULTS_DIR/assetfinder.txt" 2>/dev/null
findomain -t "$TARGET" -q > "$RESULTS_DIR/findomain.txt" 2>/dev/null

sort -u "$RESULTS_DIR/subfinder.txt" "$RESULTS_DIR/assetfinder.txt" "$RESULTS_DIR/findomain.txt" > "$RESULTS_DIR/all_subdomains.txt"
echo -e "${GREEN}[+] Found $(wc -l < "$RESULTS_DIR/all_subdomains.txt") Unique Subdomains.${NC}"

# --- Step 2: Port Scan ---
echo -e "${BLUE}[*] Running Port Scan (Top 100)...${NC}"
naabu -list "$RESULTS_DIR/all_subdomains.txt" -top-ports 100 -connect-scan -silent -o "$RESULTS_DIR/open_ports.txt" > /dev/null 2>&1

# --- Step 3: Live Web Probing ---
echo -e "${BLUE}[*] Probing For Live Web Servers...${NC}"
httpx -l "$RESULTS_DIR/all_subdomains.txt" -silent -o "$RESULTS_DIR/alive_subs.txt" > /dev/null 2>&1
ALIVE_COUNT=$(wc -l < "$RESULTS_DIR/alive_subs.txt" 2>/dev/null || echo 0)

# --- Step 4: GAU & Every GF Pattern ---
if [ "$ALIVE_COUNT" -gt 0 ]; then
    echo -e "${BLUE}[*] Fetching URLs & Running All GF Patterns...${NC}"
    cat "$RESULTS_DIR/alive_subs.txt" | gau --subs > "$RESULTS_DIR/gau.txt" 2>/dev/null
    
    # Identify GF patterns directory
    GF_PATH="$HOME/.gf"
    [ ! -d "$GF_PATH" ] && GF_PATH="$HOME/Gf-Patterns" # Backup path check

    if [ -d "$GF_PATH" ]; then
        # Loop through every available pattern file
        for pattern_file in "$GF_PATH"/*.json; do
            pattern_name=$(basename "$pattern_file" .json)
            gf "$pattern_name" "$RESULTS_DIR/gau.txt" > "$RESULTS_DIR/gf_patterns/$pattern_name.txt" 2>/dev/null
            
            # Remove empty files to keep the directory clean
            [ ! -s "$RESULTS_DIR/gf_patterns/$pattern_name.txt" ] && rm "$RESULTS_DIR/gf_patterns/$pattern_name.txt"
        done
    else
        echo -e "${RED}[!] GF patterns directory not found. Skipping GF step.${NC}"
    fi
    
    # --- Step 5: Nuclei ---
    echo -e "${BLUE}[*] Hunting For Vulnerabilities With Nuclei...${NC}"
    nuclei -l "$RESULTS_DIR/alive_subs.txt" -t ~/nuclei-templates -silent -o "$RESULTS_DIR/nuclei.txt" > /dev/null 2>&1
fi

# --- FINAL SUMMARY ---
echo -e "\n${YELLOW}================ RECON SUMMARY ================${NC}"

# 1. Interesting Ports
echo -e "${GREEN}[+] Interesting Open Ports:${NC}"
if [ -s "$RESULTS_DIR/open_ports.txt" ]; then
    INTERESTING_PORTS=$(grep -vE ':80$|:443$' "$RESULTS_DIR/open_ports.txt")
    if [ -z "$INTERESTING_PORTS" ]; then
        echo -e "    ${RED}Only standard web ports (80/443) found.${NC}"
    else
        echo "$INTERESTING_PORTS" | sed 's/^/    - /'
    fi
else
    echo -e "    ${RED}No open ports found.${NC}"
fi

echo -e ""

# 2. Nuclei Findings (Low+)
echo -e "${GREEN}[+] Nuclei Findings (Low+):${NC}"
if [ -s "$RESULTS_DIR/nuclei.txt" ]; then
    VULNS=$(grep -v "\[info\]" "$RESULTS_DIR/nuclei.txt")
    if [ -z "$VULNS" ]; then
        echo -e "    ${YELLOW}No Low/Med/High/Crit vulnerabilities found.${NC}"
    else
        echo "$VULNS" | sed 's/^/    - /'
    fi
else
    echo -e "    ${YELLOW}No vulnerabilities found.${NC}"
fi

echo -e "${YELLOW}===============================================${NC}"
echo -e "${GREEN}[+] Recon Completed. Patterns saved in: $RESULTS_DIR/gf_patterns/${NC}"
