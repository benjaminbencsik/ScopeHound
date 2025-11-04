# ScopeHound

A simple, clean, and colorized Bash script that automates the initial phase of bug bounty reconnaissance. It chains together popular tools to find subdomains, identify open ports, and probe for live web servers.

## Features

* **Tool Chaining:** Automatically runs `subfinder`, `assetfinder`, and `findomain` for subdomain enumeration.
* **Port Scanning:** Uses `naabu` to quickly scan for the top 100 open ports on all found subdomains.
* **Live Host Probing:** Feeds the `host:port` results into `httpx` to identify live web servers.
* **Clean & Colorized Output:** Hides all noisy tool banners and provides clean, color-coded status updates on its progress.
* **Organized Results:** Saves all intermediate and final files in a directory named after the target (e.g., `target.com/live_web_servers.txt`).

## Installation

1.  Clone this repository.

     ```git clone https://github.com/benjaminbencsik/ScopeHound```

3.  Make the script executable:
    
    ```chmod +x scopehound.sh```








`ScopeHound` is a wrapper script, so you must have the following tools installed and available in your system's `PATH`.

* [subfinder](https://github.com/projectdiscovery/subfinder)
* [assetfinder](https://github.com/tomnomnom/assetfinder)
* [findomain](https://github.com/findomain/findomain)
* [naabu](https://github.com/projectdiscovery/naabu)
* [httpx](https://github.com/projectdiscovery/httpx)


Usage
---
1.  Run the script against a single target domain:
    
    ```./scopehound.sh target.com```
    

Example Output
---

$ ./scopehound.sh target.com

[*] Gathering subdomains for target.com...

[+] Subdomain gathering complete.

[*] Combining and sorting unique subdomains...

[+] Found 123 unique subdomains.

[*] Running fast port scan (Top 100) on subdomains...

[+] Port scan complete.

[*] Probing for live web servers...

[+] HTTP probing complete.

--- Live Web Servers Found for target.com ---

https://www.target.com

http://dev.target.com:8080

https://api.target.com

https://store.target.com
