# 📡 ServerAlive

<div align="center">

![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge\&logo=gnubash\&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge\&logo=linux\&logoColor=black)
![Kali Linux](https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge\&logo=kalilinux\&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-a78bfa?style=for-the-badge)

**Lightweight network host discovery and availability scanner written in Bash.**

</div>

---

## Overview

ServerAlive is a lightweight Bash-based network discovery tool designed to determine whether hosts are reachable using multiple network checks.

Instead of relying only on ICMP, ServerAlive can combine **ICMP, TCP and HTTP/HTTPS detection** to identify hosts that may still be reachable when one protocol is filtered.

It supports individual targets, target lists, IPv4 CIDR subnets, custom ports, parallel execution and structured result exports.

---

## Features

```text
[+] ICMP host discovery
[+] TCP port detection
[+] HTTP / HTTPS status detection
[+] IPv4 CIDR subnet scanning
[+] Single and multiple target support
[+] Target list file support
[+] Custom ports and port ranges
[+] Configurable parallel workers
[+] Configurable connection timeout
[+] Retry configuration
[+] Duplicate target removal
[+] Alive / dead classification
[+] Terminal statistics
[+] CSV export
[+] JSON export
[+] Automatic temporary file cleanup
[+] Verbose and quiet modes
```

---

## Detection Methods

### ICMP

Uses `ping` to determine whether a host responds to ICMP echo requests.

```text
ICMP → Reachable
ICMP → No response
```

### TCP

Checks configured TCP ports using `netcat`.

Default ports:

```text
22
80
443
8080
8443
```

Custom ports are supported:

```bash
./server_alive.sh -p 22,80,443 192.168.1.1
```

Port ranges are also supported:

```bash
./server_alive.sh -p 20-25,80,443 192.168.1.1
```

### HTTP / HTTPS

Attempts HTTP and HTTPS requests and records the returned status code.

Example:

```text
HTTP:200
HTTPS:301
HTTP:403
```

A host can therefore be classified as alive even when ICMP is unavailable.

---

## Installation

### Clone

```bash
git clone https://github.com/HargosAktif/server-alive.git
cd server-alive
```

### Make executable

```bash
chmod +x server_alive.sh
```

### Install dependencies

On Kali Linux or Debian-based systems:

```bash
sudo apt install parallel netcat-openbsd curl iputils-ping
```

---

## Usage

### Single Target

```bash
./server_alive.sh 192.168.1.1
```

### Multiple Targets

```bash
./server_alive.sh 192.168.1.1 192.168.1.10 192.168.1.20
```

### Target File

```bash
./server_alive.sh -f targets.txt
```

Example `targets.txt`:

```text
192.168.1.1
192.168.1.10
192.168.1.20
example.com
```

### IPv4 Subnet

```bash
./server_alive.sh -s 192.168.1.0/24
```

### Parallel Scanning

```bash
./server_alive.sh -s 192.168.1.0/24 -j 100
```

### Custom Timeout

```bash
./server_alive.sh -t 2 192.168.1.1
```

### Retries

```bash
./server_alive.sh -r 3 192.168.1.1
```

### Disable ICMP

```bash
./server_alive.sh --no-icmp 192.168.1.1
```

### Disable HTTP Detection

```bash
./server_alive.sh --no-http 192.168.1.1
```

### Verbose Mode

```bash
./server_alive.sh -v -s 192.168.1.0/24
```

### Quiet Mode

```bash
./server_alive.sh -q -f targets.txt
```

---

## Output

A typical scan may look like:

```text
[*] Targets: 3
[*] Jobs: 50
[*] Ports: 22,80,443,8080,8443
[*] Timeout: 1s
[*] Scanning...

[+] 192.168.1.1       ICMP TCP:22,80,443 HTTP:http:200
[+] 192.168.1.10      TCP:443 HTTP:https:200
[-] 192.168.1.20      DEAD
```

### Summary

```text
┌──────────────────────────────────────────────┐
│                    SUMMARY                   │
└──────────────────────────────────────────────┘

ALIVE: 2
DEAD:  1
TOTAL: 3
TIME:  2s
SPEED: 1 hosts/s
PORTS: 22,80,443,8080,8443
```

---

## Export Results

### CSV

```bash
./server_alive.sh -f targets.txt --csv -o results.csv
```

Example:

```text
target,status,icmp,tcp_ports,http
192.168.1.1,ALIVE,1,"22 80 443","http:200"
192.168.1.10,ALIVE,0,"443","https:200"
192.168.1.20,DEAD,0,"",""
```

### JSON

```bash
./server_alive.sh -f targets.txt --json -o results.json
```

Example:

```json
{
  "version": "2.0.0",
  "elapsed": 2,
  "total": 3,
  "alive": 2,
  "dead": 1,
  "hosts": [
    {
      "target": "192.168.1.1",
      "status": "ALIVE",
      "icmp": 1,
      "tcp_ports": "22 80 443",
      "http": "http:200"
    }
  ]
}
```

---

## Command Options

| Option          | Description                               |
| --------------- | ----------------------------------------- |
| `-f, --file`    | Read targets from a file                  |
| `-s, --subnet`  | Generate targets from an IPv4 CIDR subnet |
| `-p, --ports`   | Specify ports or port ranges              |
| `-j, --jobs`    | Set the number of parallel workers        |
| `-t, --timeout` | Set connection timeout                    |
| `-r, --retries` | Set retry count                           |
| `-o, --output`  | Specify output file                       |
| `--csv`         | Export results as CSV                     |
| `--json`        | Export results as JSON                    |
| `--no-icmp`     | Disable ICMP checks                       |
| `--no-http`     | Disable HTTP/HTTPS checks                 |
| `-q, --quiet`   | Reduce terminal output                    |
| `-v, --verbose` | Enable verbose output                     |
| `--no-banner`   | Disable startup banner                    |
| `-h, --help`    | Show help                                 |

---

## Requirements

* Linux
* Bash
* GNU Parallel
* Netcat
* cURL
* ping
* GNU Coreutils

Designed and tested primarily with Kali Linux and other Debian-based Linux environments.

---

## How It Works

```text
                    Target Input
                         │
            ┌────────────┼────────────┐
            │            │            │
       Single Host    Target File    CIDR
            │            │            │
            └────────────┼────────────┘
                         │
                    Target Cleanup
                         │
                  Parallel Workers
                         │
          ┌──────────────┼──────────────┐
          │              │              │
        ICMP            TCP        HTTP/HTTPS
          │              │              │
          └──────────────┼──────────────┘
                         │
                  Result Classification
                         │
               ┌─────────┴─────────┐
               │                   │
             ALIVE                DEAD
               │
        ┌──────┴──────┐
        │             │
      Terminal     CSV / JSON
```

---

## Performance

ServerAlive uses configurable parallel workers to process multiple targets concurrently.

For example:

```bash
./server_alive.sh -s 192.168.1.0/24 -j 100
```

The number of workers can be adjusted depending on the size of the target set and the resources available on the system.

```bash
-j 25
-j 50
-j 100
-j 200
```

---

## Project Structure

```text
server-alive/
├── server_alive.sh
└── README.md
```

The scanner is intentionally kept as a **single Bash script** with no external application framework.

---

## Security & Legal Notice

ServerAlive is intended for:

* Authorized network administration
* Infrastructure testing
* Lab environments
* Security research
* Educational purposes

Only scan systems and networks that you own or have explicit authorization to test.

The author is not responsible for unauthorized use or misuse of this software.

---

<div align="center">

**ServerAlive**

by [LatenT](https://github.com/LattesGit)

</div>
