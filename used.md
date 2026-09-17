# USED TECHNOLOGIES

[![Kali Linux](https://img.shields.io/badge/Kali_Linux-557C94?style=for-the-badge\&logo=kalilinux\&logoColor=white)](https://www.kali.org/)

[![Linux](https://img.shields.io/badge/Linux-000000?style=for-the-badge\&logo=linux\&logoColor=white)](https://www.linux.org/)

[![Bash](https://img.shields.io/badge/Bash-121011?style=for-the-badge\&logo=gnubash\&logoColor=white)](https://www.gnu.org/software/bash/)

[![Networking](https://img.shields.io/badge/Networking-FF6F00?style=for-the-badge\&logo=none\&logoColor=white)]()

## Core

* Bash scripting
* GNU Coreutils
* Linux system utilities
* Temporary file management
* Process and job control

## Network Operations

* ICMP host discovery with `ping`
* TCP port detection with `netcat`
* HTTP and HTTPS status detection with `curl`
* IPv4 address validation
* CIDR subnet generation
* Custom port ranges and lists

## Scanning

* Single and multiple target scanning
* IPv4 subnet discovery
* Configurable parallel workers
* Configurable connection timeout
* Retry support
* ICMP, TCP and HTTP detection
* Duplicate target removal
* Automatic result classification

## Output

* Human readable terminal output
* CSV export
* JSON export
* Alive and dead host statistics
* Scan duration and speed statistics
* Per-host protocol and port information

## Execution Model

* Concurrent background processes
* Configurable worker count
* Temporary isolated result files
* Automatic cleanup
* Graceful interruption handling

## Concept

`server_alive` is a lightweight network host discovery tool focused on fast and simple visibility across authorized networks.

It combines ICMP, TCP and HTTP checks into a single Bash-based workflow while keeping the implementation dependency-light and easy to inspect.

## Requirements

* Linux
* Bash
* GNU parallel
* netcat
* curl
* ping
* coreutils

## Legal Notice

This project is intended for authorized network administration, testing and security research.

Only scan systems and networks you own or have explicit permission to test.

The author is not responsible for misuse or unauthorized activity.
