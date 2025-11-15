# az-nsg-portkey

A lightweight Bash utility for managing ephemeral Azure Network Security Group (NSG) rules, designed for rapid opening and closing of inbound ports on Azure VMs.

---

## Environment

- **Host:** Raspberry Pi running Debian GNU/Linux Bookworm (aarch64)  
- **Kernel:** 6.12.47+rpt-rpi-2712  
- **Shell:** Bash  
- **Azure CLI:** Required (make sure installed and configured)  

---

## Features

- List currently active ephemeral NSG rules matching `TEMP-ALLOW-*`  
- Open a specific port for TCP or UDP protocol temporarily with source IP restrictions  
- Close ephemeral NSG rules by name or port + protocol  
- Reject ports defined in a configurable reject list for security  
- Simple configuration with environment variables in `config` file  

---

## Usage

```bash
./nsgportkey.sh <command> [options]
```
Certainly! Here’s your README.md text properly formatted in clean Markdown with consistent style and spacing:

# az-nsg-portkey

A lightweight Bash utility for managing ephemeral Azure Network Security Group (NSG) rules, designed for rapid opening and closing of inbound ports on Azure VMs.

---

## Environment

- **Host:** Raspberry Pi running Debian GNU/Linux Bookworm (aarch64)  
- **Kernel:** 6.12.47+rpt-rpi-2712  
- **Shell:** Bash  
- **Azure CLI:** Required (make sure installed and configured)  

---

## Features

- List currently active ephemeral NSG rules matching `TEMP-ALLOW-*`  
- Open a specific port for TCP or UDP protocol temporarily with source IP restrictions  
- Close ephemeral NSG rules by name or port + protocol  
- Reject ports defined in a configurable reject list for security  
- Simple configuration with environment variables in `config` file  

---

## Usage

```bash
./nsgportkey.sh <command> [options]

Commands
	•	list
Lists all ephemeral NSG rules created by this tool.
	•	open <port> [tcp|udp] [hours] [source_ip]
Opens the specified <port> with the chosen protocol (tcp default).
	•	hours: Duration to keep the port open (default from config)
	•	source_ip: Source IP allowed to access the port (default from config)
	•	close <rule_name>|<port> [tcp|udp]
Closes an ephemeral NSG rule either by exact rule name or by port and protocol.
```
⸻

### Configuration

Create a config file in the same directory with the following variables:
```
RESOURCE_GROUP="your-azure-resource-group"
NSG_NAME="your-network-security-group-name"
DEFAULT_HOURS=1
DEFAULT_SOURCE_IP="*"
REJECT_PORT_FILE="reject-ports.list"
```
	•	RESOURCE_GROUP - Azure Resource Group name
	•	NSG_NAME - NSG to modify
	•	DEFAULT_HOURS - Default open time for ports in hours
	•	DEFAULT_SOURCE_IP - Default source IP allowed (e.g. * for any)
	•	REJECT_PORT_FILE - Path to port reject list file (blocks sensitive ports)

⸻

### Reject Port List

The file reject-ports.list contains ports and protocols (e.g., 22/tcp, 53/tcp/udp) which are blocked from being opened to prevent security risks.

⸻

### Prerequisites
	•	Azure CLI installed and logged in (az login)
	•	Permissions to modify NSG rules in the specified resource group
	•	Bash shell environment (tested on Debian Bookworm ARM64)

⸻

### Example

Open TCP port 222 for 2 hours from IP 10.0.0.5:

```./nsgportkey.sh open 222 tcp 2 10.0.0.5```

List ephemeral NSG rules:
```
./nsgportkey.sh list```
Close a rule by name:
```
./nsgportkey.sh close TEMP-ALLOW-222-tcp-<timestamp>
```

Close all rules on port 222 TCP:
```
./nsgportkey.sh close 222 tcp
```

---
