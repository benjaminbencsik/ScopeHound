#!/bin/bash

# ScopeHound Installer Script
# Automatically installs all required dependencies and sets up the environment

set -e

# Colors for output
GREEN="\033[1;32m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

# Banner
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}     ScopeHound Dependency Installer   ${NC}"
echo -e "${BLUE}=======================================${NC}\n"

# Check if running with sudo for potential package installs
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[i] Some tools may require elevated privileges.${NC}"
    echo -e "${YELLOW}[i] You may be prompted for your password during installation.${NC}\n"
fi

# Animation function
animate_dots() {
    local pid=$1
    local msg=$2
    local delay=0.4
    local dots=""
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r\033[K${BLUE}[*]${NC} %s%s" "$msg" "$dots"
        
        if [ "${#dots}" -eq 3 ]; then
            dots=""
        else
            dots+="."
        fi
        sleep $delay
    done
    printf "\r\033[K"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Install system packages
install_system_deps() {
    local os=$1
    echo -e "${BLUE}[*] Installing system dependencies...${NC}\n"
    
    case $os in
        debian)
            echo -e "${YELLOW}[i] Detected Debian/Ubuntu system${NC}"
            sudo apt-get update -qq
            sudo apt-get install -y -qq curl git golang-go > /dev/null 2>&1 &
            animate_dots $! "Installing system packages (apt)"
            echo -e "${GREEN}[✓] System packages installed.${NC}\n"
            ;;
        redhat)
            echo -e "${YELLOW}[i] Detected RedHat/CentOS/Fedora system${NC}"
            sudo yum groupinstall -y -q "Development Tools" > /dev/null 2>&1 &
            animate_dots $! "Installing system packages (yum)"
            sudo yum install -y -q curl git golang > /dev/null 2>&1
            echo -e "${GREEN}[✓] System packages installed.${NC}\n"
            ;;
        macos)
            echo -e "${YELLOW}[i] Detected macOS system${NC}"
            if ! command -v brew &> /dev/null; then
                echo -e "${YELLOW}[!] Homebrew not found. Installing Homebrew...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1 &
                animate_dots $! "Installing Homebrew"
            fi
            brew install curl git go > /dev/null 2>&1 &
            animate_dots $! "Installing system packages (brew)"
            echo -e "${GREEN}[✓] System packages installed.${NC}\n"
            ;;
        *)
            echo -e "${RED}[!] Unsupported OS detected. Please install Go manually.${NC}\n"
            ;;
    esac
}

# Check and install Go
check_go() {
    echo -e "${BLUE}[*] Checking Go installation...${NC}"
    if command -v go &> /dev/null; then
        local go_version=$(go version | awk '{print $3}')
        echo -e "${GREEN}[✓] Go is installed ($go_version).${NC}\n"
    else
        echo -e "${RED}[!] Go is required but not installed.${NC}"
        echo -e "${YELLOW}[i] Please visit https://golang.org/dl/ to install Go.${NC}\n"
        exit 1
    fi
}

# Setup Go paths
setup_go_paths() {
    echo -e "${BLUE}[*] Setting up Go environment...${NC}"
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin:/usr/local/bin
    
    mkdir -p "$GOPATH/bin"
    echo -e "${GREEN}[✓] Go environment configured.${NC}\n"
}

# Install Go-based tools
install_go_tools() {
    echo -e "${BLUE}[*] Installing Go-based tools...${NC}\n"
    
    declare -A tools=(
        ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
        ["assetfinder"]="github.com/tomnomnom/assetfinder@latest"
        ["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
        ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
        ["gau"]="github.com/lc/gau/v2/cmd/gau@latest"
        ["gf"]="github.com/tomnomnom/gf@latest"
        ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    )
    
    for tool in "${!tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "${GREEN}[✓] $tool already installed.${NC}"
        else
            go install -v "${tools[$tool]}" > /dev/null 2>&1 &
            animate_dots $! "Installing $tool"
            echo -e "${GREEN}[✓] $tool installed successfully.${NC}"
        fi
    done
    echo ""
}

# Install findomain (binary download)
install_findomain() {
    echo -e "${BLUE}[*] Installing findomain...${NC}"
    if command -v findomain &> /dev/null; then
        echo -e "${GREEN}[✓] findomain already installed.${NC}\n"
    else
        (
            cd /tmp
            curl -s -L https://github.com/findomain/findomain/releases/latest/download/findomain-linux -o findomain
            chmod +x findomain
            sudo mv findomain /usr/local/bin/findomain
        ) > /dev/null 2>&1 &
        animate_dots $! "Installing findomain"
        echo -e "${GREEN}[✓] findomain installed successfully.${NC}\n"
    fi
}

# Download Nuclei templates
download_nuclei_templates() {
    echo -e "${BLUE}[*] Downloading Nuclei templates...${NC}"
    if [ -d "$HOME/nuclei-templates" ]; then
        echo -e "${GREEN}[✓] Nuclei templates already present.${NC}\n"
    else
        nuclei -update-templates > /dev/null 2>&1 &
        animate_dots $! "Downloading Nuclei templates"
        echo -e "${GREEN}[✓] Nuclei templates downloaded successfully.${NC}\n"
    fi
}

# Setup bashrc
setup_bashrc() {
    echo -e "${BLUE}[*] Configuring shell environment...${NC}"
    
    local bashrc_file="$HOME/.bashrc"
    local gopath_line="export GOPATH=\$HOME/go"
    local path_line="export PATH=\$PATH:\$GOPATH/bin:/usr/local/bin"
    
    if ! grep -q "GOPATH" "$bashrc_file" 2>/dev/null; then
        {
            echo ""
            echo "# ScopeHound Environment Configuration"
            echo "$gopath_line"
            echo "$path_line"
        } >> "$bashrc_file"
        echo -e "${GREEN}[✓] Shell environment configured in ~/.bashrc${NC}"
    else
        echo -e "${GREEN}[✓] Shell environment already configured.${NC}"
    fi
    
    # Source bashrc
    if [ -f "$bashrc_file" ]; then
        source "$bashrc_file"
    fi
    echo ""
}

# Make scopehound.sh executable
setup_scopehound() {
    echo -e "${BLUE}[*] Setting up ScopeHound script...${NC}"
    if [ -f "./scopehound.sh" ]; then
        chmod +x ./scopehound.sh
        echo -e "${GREEN}[✓] scopehound.sh is now executable.${NC}\n"
    else
        echo -e "${RED}[!] scopehound.sh not found in current directory.${NC}\n"
    fi
}

# Verify installations
verify_installations() {
    echo -e "${BLUE}[*] Verifying installations...${NC}\n"
    
    local tools=("subfinder" "assetfinder" "findomain" "naabu" "httpx" "gau" "gf" "nuclei")
    local failed=0
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "${GREEN}[✓]${NC} $tool"
        else
            echo -e "${RED}[✗]${NC} $tool"
            ((failed++))
        fi
    done
    
    echo ""
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}[✓] All dependencies verified!${NC}\n"
        return 0
    else
        echo -e "${RED}[!] $failed tool(s) failed to install.${NC}\n"
        return 1
    fi
}

# Main installation flow
main() {
    local os=$(detect_os)
    
    # Step 1: Install system dependencies
    install_system_deps "$os"
    
    # Step 2: Check Go installation
    check_go
    
    # Step 3: Setup Go paths
    setup_go_paths
    
    # Step 4: Install Go tools
    install_go_tools
    
    # Step 5: Install findomain
    install_findomain
    
    # Step 6: Download Nuclei templates
    download_nuclei_templates
    
    # Step 7: Setup bashrc
    setup_bashrc
    
    # Step 8: Make scopehound.sh executable
    setup_scopehound
    
    # Step 9: Verify installations
    if verify_installations; then
        echo -e "${GREEN}=======================================${NC}"
        echo -e "${GREEN}  Installation completed successfully!  ${NC}"
        echo -e "${GREEN}=======================================${NC}\n"
        echo -e "${YELLOW}[i] Run the following to reload your shell:${NC}"
        echo -e "${BLUE}    source ~/.bashrc${NC}\n"
        echo -e "${YELLOW}[i] Then start using ScopeHound:${NC}"
        echo -e "${BLUE}    ./scopehound.sh target.com${NC}\n"
    else
        echo -e "${RED}=======================================${NC}"
        echo -e "${RED}    Installation completed with errors    ${NC}"
        echo -e "${RED}=======================================${NC}\n"
        exit 1
    fi
}

# Run main
main
