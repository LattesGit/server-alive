# SCENARIOS & DATASETS

This directory contains example datasets for **ServerAlive**.

The files provide simple test inputs for validating target parsing, port configuration, file-based scanning, and subnet discovery without requiring a custom dataset.

---

## Components

### `targets.txt`

Contains example hostnames and IPv4 addresses that can be used to test file-based target loading.

```text
example.com
192.168.1.1
192.168.1.10
```

### `custom_ports.txt`

Contains example port configurations for testing custom port lists and ranges.

```text
22
80
443
8080
8443
```

### `subnet_example.txt`

Contains example IPv4 CIDR networks for testing subnet target generation.

```text
192.168.1.0/24
10.0.0.0/24
172.16.0.0/24
```

---

## Usage

### Target Dataset

```bash
./server_alive.sh -f examples/targets.txt
```

### Custom Ports

```bash
./server_alive.sh -p "22,80,443" example.com
```

Port ranges can also be tested:

```bash
./server_alive.sh -p "20-25,80,443" 192.168.1.1
```

### Subnet Dataset

```bash
./server_alive.sh -s 192.168.1.0/24
```

---

## Example Scenarios

### Single Host

```bash
./server_alive.sh 192.168.1.1
```

Tests basic ICMP, TCP and HTTP/HTTPS detection against a single target.

### Multiple Hosts

```bash
./server_alive.sh 192.168.1.1 192.168.1.10 192.168.1.20
```

Tests multiple target handling and parallel execution.

### File-Based Scan

```bash
./server_alive.sh -f examples/targets.txt -j 50
```

Tests target file parsing, duplicate removal and configurable concurrency.

### Subnet Discovery

```bash
./server_alive.sh -s 192.168.1.0/24 -j 100
```

Tests IPv4 CIDR expansion and parallel host discovery.

### Structured Export

```bash
./server_alive.sh -f examples/targets.txt --json -o results.json
```

Tests JSON result generation.

```bash
./server_alive.sh -f examples/targets.txt --csv -o results.csv
```

Tests CSV result generation.

---

## Purpose

These datasets are useful for:

* Testing new ServerAlive releases
* Validating command-line options
* Checking output formatting
* Testing parallel execution
* Demonstrating basic usage
* Reproducing simple scanning scenarios

The examples are intentionally small and can be replaced with authorized targets appropriate for your environment.
