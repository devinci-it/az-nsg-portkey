#!/bin/bash

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$WORKDIR/config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[-] ERROR: Config file missing at $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

usage() {
    echo "Usage: $0 <list|open|close> [options]"
    echo "Commands:"
    echo "  list"
    echo "      Lists NSG rules created by az-portkey command."
    echo "  open <port> [tcp|udp] [hours] [source_ip]"
    echo "      Opens a port with specified protocol, duration and source IP."
    echo "  close <rule_name>|<port> [tcp|udp]"
    echo "      Closes the ephemeral rule by name or port+protocol."
    echo "Caveats:"
    echo "  [1] Make sure azure-cli is installed and configured in the system."
    echo "  [2] The command will assume the resourcegroup belongs to the set default account subscription set  in az-cli."
}

is_port_rejected() {
    local port="$1"
    local proto="$2"
    local file="$REJECT_PORT_FILE"

    if [ ! -f "$file" ]; then
        echo "[-] ERROR: Reject-port file not found: $file"
        exit 1
    fi

    proto=$(echo "$proto" | tr '[:upper:]' '[:lower:]')  # normalize input proto

    while IFS= read -r line; do
        # Remove comments starting with #
        line="${line%%#*}"
        # Trim whitespace
        line="$(echo "$line" | xargs)"
        [ -z "$line" ] && continue

        # Expected format: port/proto1[/proto2...]
        # Example: 53/tcp/udp or 22/tcp
        # Split line into port and protocols
        port_part="${line%%/*}"
        proto_part="${line#*/}"

        # proto_part may contain multiple protocols separated by '/'
        # Normalize protocols to lowercase
        IFS='/' read -ra protos <<< "$proto_part"
        for p in "${protos[@]}"; do
            p="$(echo "$p" | tr '[:upper:]' '[:lower:]')"
            if [[ "$p" == "$proto" ]]; then
                # Check if port_part is a range or single port
                if [[ "$port_part" == *"-"* ]]; then
                    IFS='-' read start end <<< "$port_part"
                    if (( port >= start && port <= end )); then
                        return 0
                    fi
                else
                    if (( port == port_part )); then
                        return 0
                    fi
                fi
            fi
        done
    done < "$file"

    return 1
}


list_rules() {
    echo "[+] Listing  NSG RULES (name starts with TEMP-ALLOW-):"
    az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" \
        --query "[?starts_with(name, 'TEMP-ALLOW-')].[name,priority,direction,access,destinationPortRanges,protocol,sourceAddressPrefix]" -o table
}


open_port() {
    local port="$1"
    local proto="${2:-tcp}"
    local hours="${3:-$DEFAULT_HOURS}"
    local src_ip="${4:-$DEFAULT_SOURCE_IP}"

    proto=$(echo "$proto" | tr '[:upper:]' '[:lower:]')
    if [[ "$proto" != "tcp" && "$proto" != "udp" ]]; then
        echo "[-] Protocol must be tcp or udp."
        exit 1
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        echo "[-] Invalid port number."
        exit 1
    fi

    if ! [[ "$hours" =~ ^[0-9]+$ ]]; then
        echo "[-] Hours must be a number."
        exit 1
    fi

    if is_port_rejected "$port" "$proto"; then
        echo "[-] Port $port/$proto is blocked by reject list."
        exit 1
    fi

    local rule_name="TEMP-ALLOW-${port}-${proto}-$(date +%s)"
    echo "[+] Creating NSG rule $rule_name to allow port $port/$proto for $hours hour(s), from source $src_ip"

    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "$NSG_NAME" \
        --name "$rule_name" \
        --priority 200 \
        --protocol "$proto" \
        --direction Inbound \
        --source-address-prefixes "$src_ip" \
        --source-port-ranges "*" \
        --destination-port-ranges "$port" \
        --access Allow || {
            echo "[-] Failed to create NSG rule."
            exit 1
        }

    echo "[+] Rule created. Remember to close it manually with:"
    echo "    $0 close $rule_name"
}

close_rule() {
    local identifier="$1"
    local proto="${2:-}"

    if [[ "$identifier" == TEMP-ALLOW-* ]]; then
        echo "[+] Removing NSG rule $identifier"
        az network nsg rule delete --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" --name "$identifier" || {
            echo "[-] Failed to delete rule $identifier"
            exit 1
        }
        echo "[+] Rule $identifier removed."
        return
    fi

    if ! [[ "$identifier" =~ ^[0-9]+$ ]]; then
        echo "[-] Invalid rule name or port number."
        exit 1
    fi

    if [[ -z "$proto" ]]; then
        echo "[-] When closing by port number, protocol (tcp or udp) is required."
        exit 1
    fi

    local rules
    rules=$(az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" \
        --query "[?starts_with(name, 'TEMP-ALLOW-') && destinationPortRanges[0]==\`$identifier\` && protocol==\`$proto\`].name" -o tsv)

    if [[ -z "$rules" ]]; then
        echo "[-] No ephemeral NSG rule found for port $identifier/$proto."
        exit 1
    fi

    for rule in $rules; do
        echo "[+] Removing NSG rule $rule"
        az network nsg rule delete --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" --name "$rule" || {
            echo "[-] Failed to delete rule $rule"
        }
    done
    echo "[+] Done."
}

# --- Main ---

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

cmd="$1"
shift

case "$cmd" in
    list)
        list_rules
        ;;
    open)
        open_port "$@"
        ;;
    close)
        close_rule "$@"
        ;;
    *)
        usage
        exit 1
        ;;
esac

