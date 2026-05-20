#!/bin/bash

# Machine Listing Script for Claude Code Security Auditor
# Lists all registered machines with their status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
REPO_BASE="${REPO_BASE:-$DEFAULT_DATA_DIR}"
MACHINES_DIR="$REPO_BASE/machines"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_usage() {
    cat << EOF
Usage: $0 [options] [machine_name]

Options:
  --detailed            Show detailed information for all machines
  --json                Output in JSON format
  --status              Show connection status for all machines
  <machine_name>        Show detailed info for specific machine
  --help                Show this help message

Examples:
  $0                    # List all machines (brief)
  $0 --detailed         # List all machines with details
  $0 my_server          # Show details for specific machine
  $0 --status           # Test connectivity to all machines

EOF
}

# Parse arguments
DETAILED=false
JSON_OUTPUT=false
CHECK_STATUS=false
SPECIFIC_MACHINE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --detailed)
            DETAILED=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --status)
            CHECK_STATUS=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            SPECIFIC_MACHINE="$1"
            shift
            ;;
    esac
done

# Check if machines directory exists
if [ ! -d "$MACHINES_DIR" ]; then
    echo -e "${RED}No machines registered yet${NC}"
    echo "Run './add-machine.sh' to add your first machine"
    exit 0
fi

# Get list of machines
MACHINES=($(ls -1 "$MACHINES_DIR" 2>/dev/null))

if [ ${#MACHINES[@]} -eq 0 ]; then
    echo -e "${YELLOW}No machines registered yet${NC}"
    echo "Run './add-machine.sh' to add your first machine"
    exit 0
fi

# Show specific machine
if [ -n "$SPECIFIC_MACHINE" ]; then
    MACHINE_DIR="$MACHINES_DIR/$SPECIFIC_MACHINE"

    if [ ! -d "$MACHINE_DIR" ]; then
        echo -e "${RED}Machine '$SPECIFIC_MACHINE' not found${NC}"
        exit 1
    fi

    if [ ! -f "$MACHINE_DIR/user-responses.json" ]; then
        echo -e "${RED}Machine profile incomplete${NC}"
        exit 1
    fi

    if [ "$JSON_OUTPUT" = true ]; then
        cat "$MACHINE_DIR/user-responses.json"
        exit 0
    fi

    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Machine Profile: $SPECIFIC_MACHINE"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Use Python to parse and display JSON nicely
    python3 << EOFPYTHON
import json
from datetime import datetime

with open('$MACHINE_DIR/user-responses.json') as f:
    data = json.load(f)

print("${CYAN}Basic Information${NC}")
print(f"  Name: {data.get('machine_name', 'N/A')}")
print(f"  Description: {data.get('description', 'N/A')}")
print(f"  Type: {data.get('machine_type', 'N/A')}")
print(f"  OS: {data.get('os_type', 'N/A')}")
if data.get('os_custom'):
    print(f"  OS Custom: {data['os_custom']}")
print()

print("${CYAN}Network${NC}")
print(f"  Local IP: {data.get('local_ip', 'N/A')}")
if data.get('runs_tailscale'):
    print(f"  Tailscale: Enabled")
    if data.get('tailscale_ip'):
        print(f"  Tailscale IP: {data['tailscale_ip']}")
else:
    print(f"  Tailscale: Disabled")
print()

print("${CYAN}Access${NC}")
if data.get('bash_alias'):
    print(f"  SSH Alias: {data['bash_alias']}")
else:
    print("  SSH Alias: Not configured")
if data.get('has_root_access'):
    print(f"  Root Access: Yes")
    if data.get('root_alias'):
        print(f"  Root Alias: {data['root_alias']}")
else:
    print("  Root Access: No")
print(f"  Default Access: {data.get('default_access', 'user')}")
print()

print("${CYAN}Tools${NC}")
print(f"  Claude Code: {'Installed' if data.get('claude_installed') else 'Not installed'}")
print()

print("${CYAN}Timestamps${NC}")
created = data.get('created_at', 'N/A')
updated = data.get('updated_at', 'N/A')
print(f"  Created: {created}")
print(f"  Updated: {updated}")
EOFPYTHON

    # Check for recent audits
    REPORTS_DIR="$MACHINE_DIR/reports"
    if [ -d "$REPORTS_DIR" ]; then
        AUDIT_COUNT=$(ls -1 "$REPORTS_DIR" 2>/dev/null | wc -l)
        echo ""
        echo -e "${CYAN}Audit History${NC}"
        echo "  Total Audits: $AUDIT_COUNT"

        if [ $AUDIT_COUNT -gt 0 ]; then
            LATEST_AUDIT=$(ls -1t "$REPORTS_DIR" 2>/dev/null | head -1)
            echo "  Latest Audit: $LATEST_AUDIT"
        fi
    fi

    # Test connectivity if requested
    if [ "$CHECK_STATUS" = true ]; then
        BASH_ALIAS=$(python3 -c "import json; f=open('$MACHINE_DIR/user-responses.json'); data=json.load(f); print(data.get('bash_alias', ''))")

        if [ -n "$BASH_ALIAS" ]; then
            echo ""
            echo -e "${CYAN}Connection Status${NC}"
            if ssh -o BatchMode=yes -o ConnectTimeout=5 "$BASH_ALIAS" "echo 'OK'" &>/dev/null; then
                echo -e "  Status: ${GREEN}✓ Connected${NC}"
            else
                echo -e "  Status: ${RED}✗ Unreachable${NC}"
            fi
        fi
    fi

    exit 0
fi

# List all machines
if [ "$JSON_OUTPUT" = true ]; then
    # JSON output
    echo "["
    FIRST=true
    for machine in "${MACHINES[@]}"; do
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ","
        fi

        if [ -f "$MACHINES_DIR/$machine/user-responses.json" ]; then
            cat "$MACHINES_DIR/$machine/user-responses.json"
        fi
    done
    echo ""
    echo "]"
else
    # Human-readable output
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Registered Machines                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Total machines: ${#MACHINES[@]}${NC}"
    echo ""

    if [ "$DETAILED" = true ]; then
        # Detailed listing
        for machine in "${MACHINES[@]}"; do
            MACHINE_DIR="$MACHINES_DIR/$machine"

            if [ ! -f "$MACHINE_DIR/user-responses.json" ]; then
                echo -e "${RED}⚠ $machine (incomplete profile)${NC}"
                continue
            fi

            python3 << EOFPYTHON
import json

with open('$MACHINE_DIR/user-responses.json') as f:
    data = json.load(f)

name = data.get('machine_name', '$machine')
desc = data.get('description', 'No description')
ip = data.get('local_ip', 'N/A')
alias = data.get('bash_alias', '')
os = data.get('os_type', 'Unknown')
claude = 'Yes' if data.get('claude_installed') else 'No'

print(f"${CYAN}▶ {name}${NC}")
print(f"  Description: {desc}")
print(f"  IP: {ip:<15}  OS: {os:<15}  Claude: {claude}")
if alias:
    print(f"  SSH: ssh {alias}")

# Check audit status
try:
    with open('$MACHINE_DIR/claude-profile.json') as af:
        audit_data = json.load(af)
        audit_status = audit_data.get('audit', {}).get('status', 'unknown')
        last_audit = audit_data.get('audit', {}).get('last_audit', 'never')
        if last_audit != 'never' and last_audit:
            # Format timestamp
            from datetime import datetime
            dt = datetime.fromisoformat(last_audit.replace('Z', '+00:00'))
            last_audit = dt.strftime('%Y-%m-%d %H:%M')
        print(f"  Audit Status: {audit_status:<15}  Last Audit: {last_audit}")
except:
    pass

print()
EOFPYTHON

            # Connection check if requested
            if [ "$CHECK_STATUS" = true ]; then
                BASH_ALIAS=$(python3 -c "import json; f=open('$MACHINE_DIR/user-responses.json'); data=json.load(f); print(data.get('bash_alias', ''))")

                if [ -n "$BASH_ALIAS" ]; then
                    echo -n "  Checking connection... "
                    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$BASH_ALIAS" "echo 'OK'" &>/dev/null; then
                        echo -e "${GREEN}✓ Connected${NC}"
                    else
                        echo -e "${RED}✗ Unreachable${NC}"
                    fi
                    echo ""
                fi
            fi
        done
    else
        # Brief listing
        printf "  %-20s %-35s %-15s\n" "NAME" "DESCRIPTION" "IP"
        echo "  ────────────────────────────────────────────────────────────────────"

        for machine in "${MACHINES[@]}"; do
            MACHINE_DIR="$MACHINES_DIR/$machine"

            if [ ! -f "$MACHINE_DIR/user-responses.json" ]; then
                printf "  ${RED}%-20s %-35s %-15s${NC}\n" "$machine" "(incomplete)" ""
                continue
            fi

            python3 << EOFPYTHON
import json

with open('$MACHINE_DIR/user-responses.json') as f:
    data = json.load(f)

name = data.get('machine_name', '$machine')
desc = data.get('description', 'No description')
ip = data.get('local_ip', 'N/A')

# Truncate description if too long
if len(desc) > 33:
    desc = desc[:30] + '...'

print(f"  {name:<20} {desc:<35} {ip:<15}")
EOFPYTHON
        done

        echo ""
        echo -e "${BLUE}Use --detailed for more information${NC}"
        echo -e "${BLUE}Use '<machine_name>' to view specific machine${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  ./add-machine.sh                 # Add new machine"
    echo "  ./add-machine.sh --edit <name>   # Edit existing machine"
    echo "  ./audit-machine.sh <name>        # Run security audit"
    echo "  ./list-machines.sh <name>        # View machine details"
fi
