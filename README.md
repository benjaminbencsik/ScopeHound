# ScopeHound

A simple, clean, and colorized Bash script that automates the initial phase of bug bounty reconnaissance. It chains together popular tools to find subdomains, identify open ports, and probe for live web servers.

## Features

* **Tool Chaining:** Automatically runs `subfinder`, `assetfinder`, and `findomain` for subdomain enumeration.
* **Port Scanning:** Uses `naabu` to quickly scan for the top 100 open ports on all found subdomains.
* **Live Host Probing:** Feeds the `host:port` results into `httpx` to identify live web servers.
* **Clean & Colorized Output:** Hides all noisy tool banners and provides clean, color-coded status updates on its progress.
* **Organized Results:** Saves all intermediate and final files in a directory named after the target (e.g., `target.com/live_web_servers.txt`).

## Installation

```bash
git clone https://github.com/benjaminbencsik/ScopeHound
cd ScopeHound
chmod +x installer.sh
./installer.sh
```

The installer will:
- Detect your operating system
- Install system dependencies (Go, curl, git)
- Install all required Go-based tools
- Download Nuclei templates
- Configure your shell environment
- Make ScopeHound executable

---

## Usage

Run the script against a single target domain:

```bash
./scopehound.sh example.com
```

The script will create a directory named after your target (e.g., `example.com/`) containing:
- `all_subdomains.txt` - All discovered subdomains
- `open_ports.txt` - Discovered open ports
- `alive_subs.txt` - Live web servers
- `gau.txt` - Historical URLs
- `gf_patterns/` - Pattern-matched results
- `nuclei.txt` - Vulnerability scan results

---

## Example Output

```
=======================================
        ScopeHound Recon Engine        
=======================================
[i] Target: example.com

[*] Scanning for Subdomains...
[✓] Found 342 Unique Subdomains.

[*] Scanning Top 100 Ports...
[✓] Port Scan Complete.

[*] Probing for Live Web Servers...
[✓] Found 87 Alive Hosts.

[*] Fetching URLs & processing GF patterns...
[✓] Historical URLs and GF Patterns extracted.

[*] Hunting for Vulnerabilities with Nuclei...
[✓] Vulnerability Scanning Complete.

================ RECON SUMMARY ================
[+] Interesting Open Ports:
    - api.example.com:8080
    - admin.example.com:9000
    - dev.example.com:3000

[!] Critical Patterns Found:
    - SQLi patterns found in: example.com/gf_patterns/sqli.txt
    - RCE patterns found in: example.com/gf_patterns/rce.txt

[+] Nuclei Findings (Low+):
    - [critical] example.com/admin - Authentication Bypass
    - [high] api.example.com:8080 - SQL Injection

===============================================
[✓] Done! Full data in: example.com/
```

---

## How It Works

1. **Subdomain Enumeration:** Runs three tools in parallel (`subfinder`, `assetfinder`, `findomain`) to maximize coverage
2. **Deduplication:** Combines results and removes duplicates
3. **Port Scanning:** Uses `naabu` for fast scanning of the top 100 ports
4. **Live Web Probing:** Uses `httpx` to identify which hosts are actually serving web content
5. **URL Historical Analysis:** Uses `gau` to fetch URLs from web archives
6. **Pattern Matching:** Applies `gf` patterns to find potential SQL injection, RCE, and other vulnerability signatures
7. **Vulnerability Scanning:** Runs `nuclei` templates for automated vulnerability detection

---

## Performance Tips

- Results are cached: re-running against the same target will skip completed steps
- Delete the target directory to force a full re-scan
- Run on a system with good network connectivity for best results
- Adjust tool-specific parameters in the script for custom scanning

---

## Troubleshooting

**Missing tool errors:** Run the installer script to ensure all dependencies are installed
```bash
./installer.sh
```

**Permission denied:** Make the script executable
```bash
chmod +x scopehound.sh installer.sh
```

**Tools not found:** Ensure your PATH includes Go binaries
```bash
source ~/.bashrc
```

**Nuclei templates not found:** Manually update templates
```bash
nuclei -update-templates
```

---

## License

This project is provided as-is for educational and authorized security testing purposes only.

---

## Author

[@benjaminbencsik](https://github.com/benjaminbencsik)
