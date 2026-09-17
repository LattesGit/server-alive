#!/bin/bash

# latent muck der

set -uo pipefail

RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
MAGENTA='\033[0;95m'
CYAN='\033[0;96m'
WHITE='\033[1;97m'
GRAY='\033[0;90m'
NC='\033[0m'

VERSION="2.0.0"

MAX_JOBS="${MAX_JOBS:-50}"
TIMEOUT="${TIMEOUT:-1}"
RETRIES="${RETRIES:-1}"
DEFAULT_PORTS="22 80 443 8080 8443"
OUTPUT=""
FORMAT="text"
QUIET=0
VERBOSE=0
NO_ICMP=0
NO_HTTP=0
NO_BANNER=0

declare -a TARGETS=()
declare -a PORTS=()
declare -a ALIVE_HOSTS=()
declare -a DEAD_HOSTS=()
declare -A RESULT_STATUS
declare -A RESULT_ICMP
declare -A RESULT_PORTS
declare -A RESULT_HTTP

START_TIME=0
END_TIME=0
ELAPSED=0

TMP_DIR=""

cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT INT TERM

banner() {
    [ "$NO_BANNER" -eq 1 ] && return

    printf '\n'
    printf "${WHITE}"
    printf '    ____  _____ ____  ____  _____    ____\n'
    printf '   / ___|| ____|  _ \\|  _ \\| ____|  |  _ \\\n'
    printf '   \\___ \\|  _| | |_) | | | |  _|   | |_) |\n'
    printf '    ___) | |___|  _ <| |_| | |___  |  _ <\n'
    printf '   |____/|_____|_| \\_\\\\____/|_____| |_| \\_\\\n'
    printf "${NC}"
    printf "${CYAN}Network Host Discovery & Scanner${NC}\n"
    printf "${GRAY}Legitimate network testing tool v%s${NC}\n\n" "$VERSION"
}

usage() {
    cat << EOF

${CYAN}Usage:${NC}
  $0 <target>
  $0 <target1> <target2> ...
  $0 -f targets.txt
  $0 -s 192.168.1.0/24

${CYAN}Options:${NC}
  -f, --file FILE          Read targets from file
  -s, --subnet CIDR        Scan IPv4 subnet
  -p, --ports PORTS        Ports: 22,80,443 or 20-25,80,443
  -j, --jobs NUMBER        Parallel workers
  -t, --timeout SECONDS    Connection timeout
  -r, --retries NUMBER     Retry failed checks
  -o, --output FILE        Save results
  --csv                    CSV output
  --json                   JSON output
  --no-icmp                Disable ICMP checks
  --no-http                Disable HTTP/HTTPS checks
  -q, --quiet              Minimal output
  -v, --verbose            Verbose output
  --no-banner              Hide banner
  -h, --help               Show help

${CYAN}Examples:${NC}
  $0 192.168.1.1
  $0 192.168.1.1 192.168.1.10
  $0 -s 192.168.1.0/24 -j 100
  $0 -f targets.txt -p 22,80,443
  $0 -p 20-25,80,443 example.com
  $0 -s 10.0.0.0/24 --csv -o results.csv

${CYAN}Defaults:${NC}
  Jobs:       $MAX_JOBS
  Timeout:    ${TIMEOUT}s
  Retries:    $RETRIES
  Ports:      $DEFAULT_PORTS

EOF
    exit 0
}

die() {
    printf "${RED}[!] %s${NC}\n" "$*" >&2
    exit 1
}

log() {
    [ "$QUIET" -eq 1 ] && return
    printf "%b\n" "$*"
}

debug() {
    [ "$VERBOSE" -eq 1 ] || return
    printf "${GRAY}[debug] %s${NC}\n" "$*" >&2
}

check_dependencies() {
    local missing=()

    for cmd in parallel nc curl ping timeout awk sed grep sort uniq date; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        printf "${RED}[!] Missing dependencies:${NC} %s\n" "${missing[*]}"
        printf "${YELLOW}[*] Debian/Kali:${NC} sudo apt install parallel netcat-openbsd curl iputils-ping\n"
        exit 1
    fi
}

valid_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

valid_timeout() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

valid_ipv4() {
    local ip="$1"
    local IFS=.
    local -a octets

    read -ra octets <<< "$ip"

    [ "${#octets[@]}" -eq 4 ] || return 1

    local octet

    for octet in "${octets[@]}"; do
        [[ "$octet" =~ ^[0-9]+$ ]] || return 1
        [ "$octet" -le 255 ] || return 1
    done

    return 0
}

ip_to_int() {
    local ip="$1"
    local IFS=.
    local -a o

    read -ra o <<< "$ip"

    echo $(( (${o[0]} << 24) + (${o[1]} << 16) + (${o[2]} << 8) + ${o[3]} ))
}

int_to_ip() {
    local ip="$1"

    printf '%d.%d.%d.%d\n' \
        $(( (ip >> 24) & 255 )) \
        $(( (ip >> 16) & 255 )) \
        $(( (ip >> 8) & 255 )) \
        $(( ip & 255 ))
}

generate_subnet_targets() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    [[ "$cidr" == */* ]] || die "Invalid CIDR: $cidr"
    valid_ipv4 "$ip" || die "Invalid IPv4 address: $ip"
    valid_number "$prefix" || die "Invalid CIDR prefix: $prefix"

    [ "$prefix" -ge 0 ] && [ "$prefix" -le 32 ] ||
        die "CIDR prefix must be between 0 and 32"

    local ip_int
    local mask
    local network
    local broadcast
    local first
    local last

    ip_int=$(ip_to_int "$ip")

    if [ "$prefix" -eq 0 ]; then
        mask=0
    else
        mask=$(( (0xFFFFFFFF << (32-prefix)) & 0xFFFFFFFF ))
    fi

    network=$(( ip_int & mask ))
    broadcast=$(( network | ((~mask) & 0xFFFFFFFF) ))

    if [ "$prefix" -ge 31 ]; then
        first=$network
        last=$broadcast
    else
        first=$((network + 1))
        last=$((broadcast - 1))
    fi

    local current

    for ((current=first; current<=last; current++)); do
        int_to_ip "$current"
    done
}

parse_ports() {
    local input="$1"
    local item
    local start
    local end
    local port

    input="${input//,/ }"

    read -ra items <<< "$input"

    PORTS=()

    for item in "${items[@]}"; do
        if [[ "$item" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            start="${BASH_REMATCH[1]}"
            end="${BASH_REMATCH[2]}"

            [ "$start" -le "$end" ] ||
                die "Invalid port range: $item"

            [ "$start" -ge 1 ] && [ "$end" -le 65535 ] ||
                die "Port must be between 1 and 65535"

            for ((port=start; port<=end; port++)); do
                PORTS+=("$port")
            done

        elif [[ "$item" =~ ^[0-9]+$ ]]; then
            [ "$item" -ge 1 ] && [ "$item" -le 65535 ] ||
                die "Invalid port: $item"

            PORTS+=("$item")

        else
            die "Invalid port expression: $item"
        fi
    done

    mapfile -t PORTS < <(
        printf '%s\n' "${PORTS[@]}" |
        sort -n |
        uniq
    )
}

join_ports() {
    local result=""
    local port

    for port in "${PORTS[@]}"; do
        if [ -z "$result" ]; then
            result="$port"
        else
            result="$result,$port"
        fi
    done

    printf '%s' "$result"
}

check_icmp() {
    local target="$1"

    timeout "$TIMEOUT" ping -c 1 -W 1 "$target" \
        >/dev/null 2>&1
}

check_tcp() {
    local target="$1"

    local port

    for port in "${PORTS[@]}"; do
        if timeout "$TIMEOUT" nc -z -w 1 "$target" "$port" \
            >/dev/null 2>&1; then
            printf '%s ' "$port"
        fi
    done
}

check_http() {
    local target="$1"
    local protocol
    local status

    for protocol in https http; do
        status=$(
            curl -k -s -o /dev/null \
                -w "%{http_code}" \
                --connect-timeout "$TIMEOUT" \
                --max-time "$(( ${TIMEOUT%.*} + 2 ))" \
                --head "$protocol://$target" \
                2>/dev/null || true
        )

        if [[ "$status" =~ ^[1-5][0-9][0-9]$ ]]; then
            printf '%s:%s' "$protocol" "$status"
            return 0
        fi
    done

    return 1
}

scan_target() {
    local target="$1"
    local result_file="$2"

    local icmp=0
    local tcp_ports=""
    local http_status=""

    debug "Scanning $target"

    if [ "$NO_ICMP" -eq 0 ]; then
        if check_icmp "$target"; then
            icmp=1
        fi
    fi

    tcp_ports=$(check_tcp "$target" | xargs)

    if [ "$NO_HTTP" -eq 0 ]; then
        http_status=$(check_http "$target" || true)
    fi

    if [ "$icmp" -eq 1 ] || [ -n "$tcp_ports" ] || [ -n "$http_status" ]; then
        printf 'ALIVE|%s|%s|%s|%s\n' \
            "$target" \
            "$icmp" \
            "$tcp_ports" \
            "$http_status" \
            > "$result_file"
    else
        printf 'DEAD|%s|0||\n' "$target" > "$result_file"
    fi
}

process_result_file() {
    local file="$1"

    [ -f "$file" ] || return

    local status
    local target
    local icmp
    local ports
    local http

    IFS='|' read -r status target icmp ports http < "$file"

    RESULT_STATUS["$target"]="$status"
    RESULT_ICMP["$target"]="$icmp"
    RESULT_PORTS["$target"]="$ports"
    RESULT_HTTP["$target"]="$http"

    if [ "$status" = "ALIVE" ]; then
        ALIVE_HOSTS+=("$target")
    else
        DEAD_HOSTS+=("$target")
    fi
}

prepare_targets() {
    local cleaned=()

    mapfile -t cleaned < <(
        printf '%s\n' "${TARGETS[@]}" |
        sed 's/\r$//' |
        sed '/^[[:space:]]*$/d' |
        sed 's/^[[:space:]]*//' |
        sed 's/[[:space:]]*$//' |
        grep -v '^#' |
        sort -u
    )

    TARGETS=("${cleaned[@]}")
}

run_scan() {
    local target
    local index=0
    local result_file

    for target in "${TARGETS[@]}"; do
        index=$((index + 1))

        result_file="$TMP_DIR/result_$index"

        scan_target "$target" "$result_file" &

        while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do
            wait -n 2>/dev/null || true
        done
    done

    wait

    for result_file in "$TMP_DIR"/result_*; do
        process_result_file "$result_file"
    done
}

print_host_result() {
    local target="$1"

    local status="${RESULT_STATUS[$target]:-DEAD}"
    local icmp="${RESULT_ICMP[$target]:-0}"
    local ports="${RESULT_PORTS[$target]:-}"
    local http="${RESULT_HTTP[$target]:-}"

    if [ "$status" = "ALIVE" ]; then
        printf "${GREEN}[+] %-20s${NC}" "$target"

        [ "$icmp" = "1" ] &&
            printf " ${CYAN}ICMP${NC}"

        [ -n "$ports" ] &&
            printf " ${YELLOW}TCP:%s${NC}" "$ports"

        [ -n "$http" ] &&
            printf " ${BLUE}HTTP:%s${NC}" "$http"

        printf '\n'
    elif [ "$VERBOSE" -eq 1 ]; then
        printf "${RED}[-] %-20s DEAD${NC}\n" "$target"
    fi
}

print_summary() {
    local total=$(( ${#ALIVE_HOSTS[@]} + ${#DEAD_HOSTS[@]} ))

    local speed=0

    if [ "$ELAPSED" -gt 0 ]; then
        speed=$((total / ELAPSED))
    fi

    printf '\n'
    printf "${WHITE}┌──────────────────────────────────────────────┐${NC}\n"
    printf "${WHITE}│                    SUMMARY                   │${NC}\n"
    printf "${WHITE}└──────────────────────────────────────────────┘${NC}\n\n"

    printf "${GREEN}ALIVE:${NC} %d\n" "${#ALIVE_HOSTS[@]}"
    printf "${RED}DEAD:${NC}  %d\n" "${#DEAD_HOSTS[@]}"
    printf "${WHITE}TOTAL:${NC} %d\n" "$total"
    printf "${WHITE}TIME:${NC}  %ss\n" "$ELAPSED"
    printf "${WHITE}SPEED:${NC} %s hosts/s\n" "$speed"
    printf "${WHITE}PORTS:${NC} %s\n" "$(join_ports)"

    printf '\n'

    if [ "${#ALIVE_HOSTS[@]}" -gt 0 ]; then
        printf "${GREEN}Alive hosts${NC}\n"

        for target in "${ALIVE_HOSTS[@]}"; do
            print_host_result "$target"
        done
    fi
}

write_csv() {
    local file="$1"

    {
        printf 'target,status,icmp,tcp_ports,http\n'

        local target

        for target in "${TARGETS[@]}"; do
            printf '"%s","%s","%s","%s","%s"\n' \
                "$target" \
                "${RESULT_STATUS[$target]:-DEAD}" \
                "${RESULT_ICMP[$target]:-0}" \
                "${RESULT_PORTS[$target]:-}" \
                "${RESULT_HTTP[$target]:-}"
        done
    } > "$file"
}

json_escape() {
    printf '%s' "$1" |
        sed 's/\\/\\\\/g; s/"/\\"/g'
}

write_json() {
    local file="$1"

    {
        printf '{\n'
        printf '  "version": "%s",\n' "$VERSION"
        printf '  "elapsed": %s,\n' "$ELAPSED"
        printf '  "total": %s,\n' "${#TARGETS[@]}"
        printf '  "alive": %s,\n' "${#ALIVE_HOSTS[@]}"
        printf '  "dead": %s,\n' "${#DEAD_HOSTS[@]}"
        printf '  "hosts": [\n'

        local first=1
        local target

        for target in "${TARGETS[@]}"; do
            [ "$first" -eq 1 ] || printf ',\n'
            first=0

            printf '    {\n'
            printf '      "target": "%s",\n' "$(json_escape "$target")"
            printf '      "status": "%s",\n' "${RESULT_STATUS[$target]:-DEAD}"
            printf '      "icmp": %s,\n' "${RESULT_ICMP[$target]:-0}"
            printf '      "tcp_ports": "%s",\n' "$(json_escape "${RESULT_PORTS[$target]:-}")"
            printf '      "http": "%s"\n' "$(json_escape "${RESULT_HTTP[$target]:-}")"
            printf '    }'
        done

        printf '\n  ]\n'
        printf '}\n'
    } > "$file"
}

JOBS="$MAX_JOBS"
ports_input="$DEFAULT_PORTS"

banner
check_dependencies

[ "$#" -gt 0 ] || usage

while [ "$#" -gt 0 ]; do
    case "$1" in
        -f|--file)
            [ "$#" -ge 2 ] || die "Missing file"
            [ -f "$2" ] || die "File not found: $2"
            mapfile -t TARGETS < "$2"
            shift 2
            ;;

        -s|--subnet)
            [ "$#" -ge 2 ] || die "Missing subnet"
            mapfile -t TARGETS < <(generate_subnet_targets "$2")
            shift 2
            ;;

        -p|--ports)
            [ "$#" -ge 2 ] || die "Missing ports"
            ports_input="$2"
            shift 2
            ;;

        -j|--jobs)
            [ "$#" -ge 2 ] || die "Missing jobs"
            valid_number "$2" || die "Jobs must be a number"
            [ "$2" -ge 1 ] || die "Jobs must be greater than 0"
            JOBS="$2"
            shift 2
            ;;

        -t|--timeout)
            [ "$#" -ge 2 ] || die "Missing timeout"
            valid_timeout "$2" || die "Invalid timeout"
            TIMEOUT="$2"
            shift 2
            ;;

        -r|--retries)
            [ "$#" -ge 2 ] || die "Missing retries"
            valid_number "$2" || die "Retries must be a number"
            RETRIES="$2"
            shift 2
            ;;

        -o|--output)
            [ "$#" -ge 2 ] || die "Missing output file"
            OUTPUT="$2"
            shift 2
            ;;

        --csv)
            FORMAT="csv"
            shift
            ;;

        --json)
            FORMAT="json"
            shift
            ;;

        --no-icmp)
            NO_ICMP=1
            shift
            ;;

        --no-http)
            NO_HTTP=1
            shift
            ;;

        --no-banner)
            NO_BANNER=1
            shift
            ;;

        -q|--quiet)
            QUIET=1
            shift
            ;;

        -v|--verbose)
            VERBOSE=1
            shift
            ;;

        -h|--help)
            usage
            ;;

        -*)
            die "Unknown option: $1"
            ;;

        *)
            TARGETS+=("$1")
            shift
            ;;
    esac
done

parse_ports "$ports_input"
prepare_targets

[ "${#TARGETS[@]}" -gt 0 ] ||
    die "No targets supplied"

[ "${#PORTS[@]}" -gt 0 ] ||
    die "No ports supplied"

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/server_alive.XXXXXX")

START_TIME=$(date +%s)

if [ "$QUIET" -eq 0 ]; then
    printf "${CYAN}[*] Targets:${NC} %d\n" "${#TARGETS[@]}"
    printf "${CYAN}[*] Jobs:${NC} %d\n" "$JOBS"
    printf "${CYAN}[*] Ports:${NC} %s\n" "$(join_ports)"
    printf "${CYAN}[*] Timeout:${NC} %ss\n" "$TIMEOUT"
    printf "${CYAN}[*] Scanning...${NC}\n\n"
fi

run_scan

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

case "$FORMAT" in
    csv)
        if [ -z "$OUTPUT" ]; then
            OUTPUT="scan_results.csv"
        fi

        write_csv "$OUTPUT"
        printf "${GREEN}[+] CSV saved: %s${NC}\n" "$OUTPUT"
        ;;

    json)
        if [ -z "$OUTPUT" ]; then
            OUTPUT="scan_results.json"
        fi

        write_json "$OUTPUT"
        printf "${GREEN}[+] JSON saved: %s${NC}\n" "$OUTPUT"
        ;;

    text)
        print_summary
        ;;
esac
