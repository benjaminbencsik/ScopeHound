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

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}        ScopeHound Recon Engine        ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "${YELLOW}[i] Target: $TARGET${NC}\n"

# --- ANIMATION FUNCTION ---
# Creates a universally supported . .. ... looping animation
animate_dots() {
    local pid=$1
    local msg=$2
    local delay=0.4
    local dots=""
    
    while kill -0 "$pid" 2>/dev/null; do
        # \033[K clears the line from the cursor to the end, preventing text overlap
        printf "\r\033[K${BLUE}[*]${NC} %s%s" "$msg" "$dots"
        
        if [ "${#dots}" -eq 3 ]; then
            dots=""
        else
            dots+="."
        fi
        sleep $delay
    done
    printf "\r\033[K" # Clear the animated line completely when the process finishes
}

# --- DEPENDENCY INSTALLER ---
install_dependencies() {
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin:/usr/local/bin

    if ! command -v go &> /dev/null; then
        echo -e "${RED}[!] Go is required but not installed. Please install Go to proceed.${NC}"
        exit 1
    fi

    declare -A tools=(
        ["subfinder"]="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        ["assetfinder"]="go install github.com/tomnomnom/assetfinder@latest"
        ["naabu"]="go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        ["httpx"]="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
        ["gau"]="go install github.com/lc/gau/v2/cmd/gau@latest"
        ["gf"]="go install github.com/tomnomnom/gf@latest"
        ["nuclei"]="go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    )

    for tool in "${!tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            ${tools[$tool]} > /dev/null 2>&1 &
            animate_dots $! "Installing missing tool: $tool"
            echo -e "${GREEN}[✓] $tool installed!${NC}"
        fi
    done

    if ! command -v findomain &> /dev/null; then
        (
            curl -s -O https://github.com/findomain/findomain/releases/latest/download/findomain-linux
            chmod +x findomain-linux
            sudo mv findomain-linux /usr/local/bin/findomain
        ) > /dev/null 2>&1 &
        animate_dots $! "Installing missing tool: findomain"
        echo -e "${GREEN}[✓] findomain installed!${NC}"
    fi

    if [ ! -d "$HOME/nuclei-templates" ]; then
        nuclei -update-templates > /dev/null 2>&1 &
        animate_dots $! "Downloading Nuclei templates"
        echo -e "${GREEN}[✓] Nuclei templates updated!${NC}"
    fi
}

install_dependencies

# --- Step 1: Subdomain Enumeration ---
if [ -s "$RESULTS_DIR/all_subdomains.txt" ]; then
    echo -e "${GREEN}[✓] Subdomains already gathered. Skipping...${NC}"
else
    # We wrap the parallel commands in a function so we can animate its total runtime
    gather_subs() {
        subfinder -d "$TARGET" -silent -o "$RESULTS_DIR/subfinder.txt" > /dev/null 2>&1 &
        assetfinder --subs-only "$TARGET" > "$RESULTS_DIR/assetfinder.txt" 2>/dev/null &
        findomain -t "$TARGET" -q > "$RESULTS_DIR/findomain.txt" 2>/dev/null &
        wait
        sort -u "$RESULTS_DIR/subfinder.txt" "$RESULTS_DIR/assetfinder.txt" "$RESULTS_DIR/findomain.txt" > "$RESULTS_DIR/all_subdomains.txt"
    }
    
    gather_subs &
    animate_dots $! "Scanning for Subdomains"
    echo -e "${GREEN}[✓] Found $(wc -l < "$RESULTS_DIR/all_subdomains.txt") Unique Subdomains.${NC}"
fi

# --- Step 2: Port Scan ---
if [ -s "$RESULTS_DIR/open_ports.txt" ]; then
    echo -e "${GREEN}[✓] Port scan already completed. Skipping...${NC}"
else
    naabu -list "$RESULTS_DIR/all_subdomains.txt" -top-ports 100 -connect-scan -silent -o "$RESULTS_DIR/open_ports.txt" > /dev/null 2>&1 &
    animate_dots $! "Scanning Top 100 Ports"
    echo -e "${GREEN}[✓] Port Scan Complete.${NC}"
fi

# --- Step 3: Live Web Probing ---
if [ -s "$RESULTS_DIR/alive_subs.txt" ]; then
    echo -e "${GREEN}[✓] Live probing already completed. Skipping...${NC}"
else
    httpx -l "$RESULTS_DIR/all_subdomains.txt" -silent -o "$RESULTS_DIR/alive_subs.txt" > /dev/null 2>&1 &
    animate_dots $! "Probing for Live Web Servers"
    ALIVE_COUNT=$(wc -l < "$RESULTS_DIR/alive_subs.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[✓] Found $ALIVE_COUNT Alive Hosts.${NC}"
fi

ALIVE_COUNT=$(wc -l < "$RESULTS_DIR/alive_subs.txt" 2>/dev/null || echo 0)

# --- Step 4: GAU & Every GF Pattern ---
if [ "$ALIVE_COUNT" -gt 0 ]; then
    if [ -s "$RESULTS_DIR/gau.txt" ]; then
        echo -e "${GREEN}[✓] URLs and GF patterns already completed. Skipping...${NC}"
    else
        process_gf() {
            cat "$RESULTS_DIR/alive_subs.txt" | gau --subs > "$RESULTS_DIR/gau.txt" 2>/dev/null
            
            GF_PATH="$HOME/.gf"
            [ ! -d "$GF_PATH" ] && GF_PATH="$HOME/Gf-Patterns"

            if [ -d "$GF_PATH" ]; then
                for pattern_file in "$GF_PATH"/*.json; do
                    pattern_name=$(basename "$pattern_file" .json)
                    gf "$pattern_name" "$RESULTS_DIR/gau.txt" > "$RESULTS_DIR/gf_patterns/$pattern_name.txt" 2>/dev/null
                    [ ! -s "$RESULTS_DIR/gf_patterns/$pattern_name.txt" ] && rm "$RESULTS_DIR/gf_patterns/$pattern_name.txt"
                done
            fi
        }
        
        process_gf &
        animate_dots $! "Fetching URLs & processing GF patterns"
        echo -e "${GREEN}[✓] Historical URLs and GF Patterns extracted.${NC}"
    fi

    # --- Step 5: Nuclei ---
    if [ -s "$RESULTS_DIR/nuclei.txt" ]; then
        echo -e "${GREEN}[✓] Nuclei scan already completed. Skipping...${NC}"
    else
        nuclei -l "$RESULTS_DIR/alive_subs.txt" -t ~/nuclei-templates -silent -o "$RESULTS_DIR/nuclei.txt" > /dev/null 2>&1 &
        animate_dots $! "Hunting for Vulnerabilities with Nuclei"
        echo -e "${GREEN}[✓] Vulnerability Scanning Complete.${NC}"
    fi
fi

# --- FINAL SUMMARY ---
echo -e "\n${BLUE}================ RECON SUMMARY ================${NC}"

# 1. Interesting Ports
echo -e "${GREEN}[+] Interesting Open Ports:${NC}"
if [ -s "$RESULTS_DIR/open_ports.txt" ]; then
    INTERESTING_PORTS=$(grep -vE ':80$|:443$' "$RESULTS_DIR/open_ports.txt")
    if [ -z "$INTERESTING_PORTS" ]; then
        echo -e "    ${RED}Only standard web ports (80/443).${NC}"
    else
        echo "$INTERESTING_PORTS" | sed 's/^/    - /'
    fi
else
    echo -e "    ${RED}No open ports found.${NC}"
fi

echo -e ""

# 2. Priority GF Hits (SQLi / RCE)
if [ -f "$RESULTS_DIR/gf_patterns/sqli.txt" ] || [ -f "$RESULTS_DIR/gf_patterns/rce.txt" ]; then
    echo -e "${RED}[!] Critical Patterns Found:${NC}"
    [ -f "$RESULTS_DIR/gf_patterns/sqli.txt" ] && echo -e "    - SQLi patterns found in: $RESULTS_DIR/gf_patterns/sqli.txt"
    [ -f "$RESULTS_DIR/gf_patterns/rce.txt" ] && echo -e "    - RCE patterns found in: $RESULTS_DIR/gf_patterns/rce.txt"
    echo -e ""
fi

# 3. Nuclei Findings (Low+)
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

echo -e "${BLUE}===============================================${NC}"
echo -e "${GREEN}[✓] Done! Full data in: $RESULTS_DIR${NC}"
