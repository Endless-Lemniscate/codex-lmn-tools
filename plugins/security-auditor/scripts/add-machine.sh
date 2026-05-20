#!/bin/bash

# Machine Addition Script for Claude Code Security Auditor
# This script guides you through adding a new machine to the security audit system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
REPO_BASE="${REPO_BASE:-$DEFAULT_DATA_DIR}"
MACHINES_DIR="$REPO_BASE/machines"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to convert to snake_case
to_snake_case() {
    echo "$1" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/_\+/_/g' | tr '[:upper:]' '[:lower:]' | sed 's/^_//;s/_$//'
}

# Helper function to prompt with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local response

    if [ -n "$default" ]; then
        read -p "$(echo -e "${BLUE}${prompt} [${default}]: ${NC}")" response
        echo "${response:-$default}"
    else
        read -p "$(echo -e "${BLUE}${prompt}: ${NC}")" response
        echo "$response"
    fi
}

# Helper function for yes/no prompts
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    while true; do
        read -p "$(echo -e "${BLUE}${prompt} (y/n) [${default}]: ${NC}")" response
        response="${response:-$default}"
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) echo "yes"; return 0 ;;
            [Nn]|[Nn][Oo]) echo "no"; return 0 ;;
            *) echo -e "${RED}Please answer yes or no${NC}" ;;
        esac
    done
}

# Helper function for menu selection
prompt_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "${BLUE}${prompt}${NC}" >&2
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}" >&2
    done

    while true; do
        read -p "$(echo -e "${BLUE}Select option (1-${#options[@]}): ${NC}")" selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
            echo "${options[$((selection-1))]}"
            return 0
        fi
        echo -e "${RED}Invalid selection. Please choose 1-${#options[@]}${NC}" >&2
    done
}

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Claude Code Security Auditor - Add Machine   ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo ""

# Check if editing mode
EDIT_MODE=false
if [ "$1" == "--edit" ] && [ -n "$2" ]; then
    EDIT_MODE=true
    MACHINE_NAME="$2"
    MACHINE_DIR="$MACHINES_DIR/$MACHINE_NAME"

    if [ ! -d "$MACHINE_DIR" ]; then
        echo -e "${RED}Error: Machine '$MACHINE_NAME' not found${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Editing existing machine: $MACHINE_NAME${NC}"
    echo ""

    # Load existing responses
    if [ -f "$MACHINE_DIR/user-responses.json" ]; then
        source <(python3 -c "
import json, sys
with open('$MACHINE_DIR/user-responses.json') as f:
    data = json.load(f)
    for k, v in data.items():
        if isinstance(v, bool):
            print(f'{k.upper()}={\"yes\" if v else \"no\"}')
        elif v is None:
            print(f'{k.upper()}=\"\"')
        else:
            print(f'{k.upper()}=\"{v}\"')
" 2>/dev/null || true)
    fi
fi

# Step 1: Machine Name
if [ "$EDIT_MODE" = false ]; then
    echo -e "${YELLOW}Step 1: Machine Identification${NC}"
    MACHINE_NAME_INPUT=$(prompt_with_default "Enter machine name" "")
    MACHINE_NAME=$(to_snake_case "$MACHINE_NAME_INPUT")

    if [ "$MACHINE_NAME" != "$MACHINE_NAME_INPUT" ]; then
        echo -e "${YELLOW}Converted to snake_case: $MACHINE_NAME${NC}"
    fi

    MACHINE_DIR="$MACHINES_DIR/$MACHINE_NAME"

    if [ -d "$MACHINE_DIR" ]; then
        echo -e "${RED}Error: Machine '$MACHINE_NAME' already exists. Use --edit flag to modify.${NC}"
        exit 1
    fi
fi

# Step 2: Machine Description
echo ""
echo -e "${YELLOW}Step 2: Machine Purpose${NC}"
DESCRIPTION=$(prompt_with_default "Enter machine description/purpose" "${DESCRIPTION:-}")

# Step 3: Network Information
echo ""
echo -e "${YELLOW}Step 3: Network Configuration${NC}"
LOCAL_IP=$(prompt_with_default "Enter local IP address" "${LOCAL_IP:-}")
HAS_BASH_ALIAS=$(prompt_yes_no "Does this machine have a bash alias?" "${HAS_BASH_ALIAS:-n}")

if [ "$HAS_BASH_ALIAS" = "yes" ]; then
    BASH_ALIAS=$(prompt_with_default "Enter bash alias name" "${BASH_ALIAS:-$MACHINE_NAME}")
else
    BASH_ALIAS=""
fi

RUNS_TAILSCALE=$(prompt_yes_no "Does this machine run Tailscale?" "${RUNS_TAILSCALE:-n}")
if [ "$RUNS_TAILSCALE" = "yes" ]; then
    TAILSCALE_IP=$(prompt_with_default "Enter Tailscale IP (optional)" "${TAILSCALE_IP:-}")
else
    TAILSCALE_IP=""
fi

# Step 4: Access Configuration
echo ""
echo -e "${YELLOW}Step 4: Access Configuration${NC}"
HAS_ROOT_ACCESS=$(prompt_yes_no "Do you have root access?" "${HAS_ROOT_ACCESS:-n}")

if [ "$HAS_ROOT_ACCESS" = "yes" ]; then
    HAS_SEPARATE_ROOT_ALIAS=$(prompt_yes_no "Does root have a separate alias?" "${HAS_SEPARATE_ROOT_ALIAS:-n}")
    if [ "$HAS_SEPARATE_ROOT_ALIAS" = "yes" ]; then
        ROOT_ALIAS=$(prompt_with_default "Enter root alias name" "${ROOT_ALIAS:-${BASH_ALIAS}-root}")
    else
        ROOT_ALIAS=""
    fi
else
    HAS_SEPARATE_ROOT_ALIAS="no"
    ROOT_ALIAS=""
fi

DEFAULT_ACCESS=$(prompt_menu "Default access should be via:" "user" "root")

# Step 5: System Information
echo ""
echo -e "${YELLOW}Step 5: System Information${NC}"
OS_TYPE=$(prompt_menu "Select operating system:" "Linux" "Windows" "macOS" "Raspberry Pi" "Orange Pi" "Other")

if [ "$OS_TYPE" = "Other" ]; then
    OS_CUSTOM=$(prompt_with_default "Specify OS type" "${OS_CUSTOM:-}")
else
    OS_CUSTOM=""
fi

MACHINE_TYPE=$(prompt_menu "Machine type:" "Desktop" "Server" "Laptop" "VM" "Container" "Embedded")

# Step 6: Claude Code Status
echo ""
echo -e "${YELLOW}Step 6: Claude Code Configuration${NC}"
CLAUDE_INSTALLED=$(prompt_yes_no "Is Claude Code/CLI installed?" "${CLAUDE_INSTALLED:-n}")

# Create machine directory structure
echo ""
echo -e "${YELLOW}Creating machine directory structure...${NC}"
mkdir -p "$MACHINE_DIR/reports"

# Create user-responses.json
cat > "$MACHINE_DIR/user-responses.json" << EOF
{
  "machine_name": "$MACHINE_NAME",
  "machine_name_original": "$MACHINE_NAME_INPUT",
  "description": "$DESCRIPTION",
  "local_ip": "$LOCAL_IP",
  "has_bash_alias": $([ "$HAS_BASH_ALIAS" = "yes" ] && echo "true" || echo "false"),
  "bash_alias": $([ -n "$BASH_ALIAS" ] && echo "\"$BASH_ALIAS\"" || echo "null"),
  "runs_tailscale": $([ "$RUNS_TAILSCALE" = "yes" ] && echo "true" || echo "false"),
  "tailscale_ip": $([ -n "$TAILSCALE_IP" ] && echo "\"$TAILSCALE_IP\"" || echo "null"),
  "has_root_access": $([ "$HAS_ROOT_ACCESS" = "yes" ] && echo "true" || echo "false"),
  "has_separate_root_alias": $([ "$HAS_SEPARATE_ROOT_ALIAS" = "yes" ] && echo "true" || echo "false"),
  "root_alias": $([ -n "$ROOT_ALIAS" ] && echo "\"$ROOT_ALIAS\"" || echo "null"),
  "default_access": "$DEFAULT_ACCESS",
  "os_type": "$OS_TYPE",
  "os_custom": $([ -n "$OS_CUSTOM" ] && echo "\"$OS_CUSTOM\"" || echo "null"),
  "machine_type": "$MACHINE_TYPE",
  "claude_installed": $([ "$CLAUDE_INSTALLED" = "yes" ] && echo "true" || echo "false"),
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

# Create user-responses.md
cat > "$MACHINE_DIR/user-responses.md" << EOF
# User Responses for $MACHINE_NAME

## Machine Identification
- **Machine Name**: $MACHINE_NAME
- **Original Input**: $MACHINE_NAME_INPUT
- **Description**: $DESCRIPTION

## Network Configuration
- **Local IP**: $LOCAL_IP
- **Has Bash Alias**: $HAS_BASH_ALIAS
$([ -n "$BASH_ALIAS" ] && echo "- **Bash Alias**: $BASH_ALIAS")
- **Runs Tailscale**: $RUNS_TAILSCALE
$([ -n "$TAILSCALE_IP" ] && echo "- **Tailscale IP**: $TAILSCALE_IP")

## Access Configuration
- **Has Root Access**: $HAS_ROOT_ACCESS
$([ "$HAS_ROOT_ACCESS" = "yes" ] && echo "- **Has Separate Root Alias**: $HAS_SEPARATE_ROOT_ALIAS")
$([ -n "$ROOT_ALIAS" ] && echo "- **Root Alias**: $ROOT_ALIAS")
- **Default Access**: $DEFAULT_ACCESS

## System Information
- **OS Type**: $OS_TYPE
$([ -n "$OS_CUSTOM" ] && echo "- **Custom OS**: $OS_CUSTOM")
- **Machine Type**: $MACHINE_TYPE

## Claude Code Status
- **Claude Installed**: $CLAUDE_INSTALLED

---
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
*Updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

# Create readable-profile.md
cat > "$MACHINE_DIR/readable-profile.md" << EOF
# Machine Profile: $MACHINE_NAME

## Overview
**$MACHINE_NAME** is a $MACHINE_TYPE running $OS_TYPE$([ -n "$OS_CUSTOM" ] && echo " ($OS_CUSTOM)").

**Purpose**: $DESCRIPTION

## Network Access
- **Local IP**: $LOCAL_IP
$([ "$HAS_BASH_ALIAS" = "yes" ] && echo "- **SSH Alias**: \`$BASH_ALIAS\`")
$([ "$RUNS_TAILSCALE" = "yes" ] && [ -n "$TAILSCALE_IP" ] && echo "- **Tailscale IP**: $TAILSCALE_IP")

## Access Methods
$(if [ "$HAS_BASH_ALIAS" = "yes" ]; then
    echo "Connect via SSH alias:"
    echo '```bash'
    echo "ssh $BASH_ALIAS"
    echo '```'
else
    echo "Connect via direct SSH:"
    echo '```bash'
    echo "ssh user@$LOCAL_IP"
    echo '```'
fi)

$(if [ "$HAS_ROOT_ACCESS" = "yes" ]; then
    if [ "$HAS_SEPARATE_ROOT_ALIAS" = "yes" ]; then
        echo "Root access via separate alias:"
        echo '```bash'
        echo "ssh $ROOT_ALIAS"
        echo '```'
    else
        echo "Root access available (use sudo or su after connecting)"
    fi
fi)

**Default Access Level**: $DEFAULT_ACCESS

## Tools & Environment
- **Claude Code Installed**: $([ "$CLAUDE_INSTALLED" = "yes" ] && echo "Yes ✓" || echo "No ✗")

## Security Audit Status
- Initial profile created: $(date +"%Y-%m-%d")
- Last audit: Not yet audited
- Audit reports available in: \`reports/\`

---
*This profile was generated automatically by the Claude Code Security Auditor system.*
EOF

# Create claude-profile.json (for programmatic access)
cat > "$MACHINE_DIR/claude-profile.json" << EOF
{
  "version": "1.0",
  "machine": {
    "name": "$MACHINE_NAME",
    "description": "$DESCRIPTION",
    "type": "$MACHINE_TYPE",
    "os": {
      "type": "$OS_TYPE",
      "custom": $([ -n "$OS_CUSTOM" ] && echo "\"$OS_CUSTOM\"" || echo "null")
    }
  },
  "network": {
    "local_ip": "$LOCAL_IP",
    "tailscale_enabled": $([ "$RUNS_TAILSCALE" = "yes" ] && echo "true" || echo "false"),
    "tailscale_ip": $([ -n "$TAILSCALE_IP" ] && echo "\"$TAILSCALE_IP\"" || echo "null")
  },
  "access": {
    "bash_alias": $([ -n "$BASH_ALIAS" ] && echo "\"$BASH_ALIAS\"" || echo "null"),
    "root_alias": $([ -n "$ROOT_ALIAS" ] && echo "\"$ROOT_ALIAS\"" || echo "null"),
    "default_user": "$DEFAULT_ACCESS",
    "root_available": $([ "$HAS_ROOT_ACCESS" = "yes" ] && echo "true" || echo "false")
  },
  "tools": {
    "claude_code": {
      "installed": $([ "$CLAUDE_INSTALLED" = "yes" ] && echo "true" || echo "false"),
      "version": null
    }
  },
  "audit": {
    "status": "not_started",
    "last_audit": null,
    "reports_dir": "reports/"
  },
  "metadata": {
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "managed_by": "claude-code-security-auditor"
  }
}
EOF

# Create initial audit-log.json
cat > "$MACHINE_DIR/audit-log.json" << EOF
{
  "machine": "$MACHINE_NAME",
  "log_version": "1.0",
  "events": [
    {
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "event_type": "machine_created",
      "description": "Machine profile created",
      "user": "$USER",
      "details": {
        "method": "add-machine.sh",
        "edit_mode": $([ "$EDIT_MODE" = true ] && echo "true" || echo "false")
      }
    }
  ]
}
EOF

echo -e "${GREEN}✓ Machine profile created successfully${NC}"
echo ""

# Step 7: SSH Connection Test (only if not editing and has SSH alias)
if [ "$EDIT_MODE" = false ] && [ "$HAS_BASH_ALIAS" = "yes" ]; then
    echo -e "${YELLOW}Step 7: Connection Test${NC}"

    if [ "$(prompt_yes_no "Would you like to test SSH connection now?" "y")" = "yes" ]; then
        echo ""
        echo -e "${BLUE}Testing SSH connection to $BASH_ALIAS...${NC}"

        if ssh -o BatchMode=yes -o ConnectTimeout=5 "$BASH_ALIAS" "echo 'Connection successful'" 2>/dev/null; then
            echo -e "${GREEN}✓ SSH connection successful${NC}"

            # Check for Claude Code
            echo ""
            echo -e "${BLUE}Checking for Claude Code installation...${NC}"

            if ssh "$BASH_ALIAS" "command -v claude &>/dev/null"; then
                echo -e "${GREEN}✓ Claude Code is installed${NC}"

                # Update the profile
                python3 -c "
import json
with open('$MACHINE_DIR/user-responses.json', 'r+') as f:
    data = json.load(f)
    data['claude_installed'] = True
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
                python3 -c "
import json
with open('$MACHINE_DIR/claude-profile.json', 'r+') as f:
    data = json.load(f)
    data['tools']['claude_code']['installed'] = True
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
            else
                echo -e "${YELLOW}⚠ Claude Code not found${NC}"

                if [ "$(prompt_yes_no "Would you like to install Claude Code on this machine?" "n")" = "yes" ]; then
                    echo ""
                    echo -e "${BLUE}Installing Claude Code...${NC}"
                    ssh "$BASH_ALIAS" "bash -c '\$(curl -fsSL https://raw.githubusercontent.com/anthropics/claude-code/main/install.sh)'"

                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✓ Claude Code installed successfully${NC}"

                        # Update the profile
                        python3 -c "
import json
with open('$MACHINE_DIR/user-responses.json', 'r+') as f:
    data = json.load(f)
    data['claude_installed'] = True
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
                        python3 -c "
import json
with open('$MACHINE_DIR/claude-profile.json', 'r+') as f:
    data = json.load(f)
    data['tools']['claude_code']['installed'] = True
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
                    else
                        echo -e "${RED}✗ Failed to install Claude Code${NC}"
                    fi
                fi
            fi

            # Check for CLAUDE.md
            echo ""
            echo -e "${BLUE}Checking for CLAUDE.md files...${NC}"

            HOME_CLAUDE=$(ssh "$BASH_ALIAS" "[ -f ~/CLAUDE.md ] && echo 'exists' || echo 'missing'")
            ROOT_CLAUDE=$(ssh "$BASH_ALIAS" "sudo [ -f /root/CLAUDE.md ] 2>/dev/null && echo 'exists' || echo 'missing'" 2>/dev/null || echo "no_access")

            if [ "$HOME_CLAUDE" = "missing" ]; then
                echo -e "${YELLOW}⚠ No CLAUDE.md found in home directory${NC}"

                if [ "$(prompt_yes_no "Would you like to create a CLAUDE.md with machine context?" "y")" = "yes" ]; then
                    # Generate CLAUDE.md content
                    CLAUDE_MD_CONTENT="# CLAUDE.md for $MACHINE_NAME

## Machine Purpose

$DESCRIPTION

## System Information

- **Machine Type**: $MACHINE_TYPE
- **Operating System**: $OS_TYPE$([ -n "$OS_CUSTOM" ] && echo " ($OS_CUSTOM)")
- **Local IP**: $LOCAL_IP
$([ "$RUNS_TAILSCALE" = "yes" ] && [ -n "$TAILSCALE_IP" ] && echo "- **Tailscale IP**: $TAILSCALE_IP")

## Security Audit Context

This machine is part of the Claude Code Security Auditor system. Regular security audits will be performed to ensure:

- Antivirus is installed and configured
- Automatic definition updates are enabled
- Rootkit detection tools are installed
- System permissions are properly configured
- Security best practices are followed

## Access Information

$(if [ "$HAS_ROOT_ACCESS" = "yes" ]; then
    echo "- Root access: Available"
    echo "- Default access level: $DEFAULT_ACCESS"
else
    echo "- Root access: Not available"
    echo "- User-level access only"
fi)

## Audit Records

Security audit records are stored in the central repository at:
\`~/repos/github/Claude-Code-Security-Auditor/machines/$MACHINE_NAME/reports/\`

---
*This file was automatically generated by Claude Code Security Auditor*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*"

                    # Upload CLAUDE.md
                    echo "$CLAUDE_MD_CONTENT" | ssh "$BASH_ALIAS" "cat > ~/CLAUDE.md"

                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✓ CLAUDE.md created successfully${NC}"
                    else
                        echo -e "${RED}✗ Failed to create CLAUDE.md${NC}"
                    fi
                fi
            else
                echo -e "${GREEN}✓ CLAUDE.md already exists in home directory${NC}"
            fi

            if [ "$ROOT_CLAUDE" = "missing" ] && [ "$HAS_ROOT_ACCESS" = "yes" ]; then
                echo -e "${YELLOW}⚠ No CLAUDE.md found in /root${NC}"

                if [ "$(prompt_yes_no "Would you like to create a CLAUDE.md in /root?" "n")" = "yes" ]; then
                    CLAUDE_MD_CONTENT="# CLAUDE.md for $MACHINE_NAME (Root)

## Machine Purpose

$DESCRIPTION

## System Information

- **Machine Type**: $MACHINE_TYPE
- **Operating System**: $OS_TYPE$([ -n "$OS_CUSTOM" ] && echo " ($OS_CUSTOM)")
- **Local IP**: $LOCAL_IP

## Security Audit Context (Root Level)

This machine is part of the Claude Code Security Auditor system. Root-level security audits include:

- System-wide security configuration
- Kernel-level security settings
- Service hardening
- System-wide permissions audit
- Critical system file integrity

## Access Information

- Root access: Available
- Access via: $([ "$HAS_SEPARATE_ROOT_ALIAS" = "yes" ] && echo "$ROOT_ALIAS" || echo "sudo/su from user account")

---
*This file was automatically generated by Claude Code Security Auditor*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*"

                    echo "$CLAUDE_MD_CONTENT" | ssh "$BASH_ALIAS" "sudo tee /root/CLAUDE.md > /dev/null"

                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✓ Root CLAUDE.md created successfully${NC}"
                    else
                        echo -e "${RED}✗ Failed to create root CLAUDE.md${NC}"
                    fi
                fi
            elif [ "$ROOT_CLAUDE" = "exists" ]; then
                echo -e "${GREEN}✓ CLAUDE.md already exists in /root${NC}"
            fi

        else
            echo -e "${RED}✗ SSH connection failed${NC}"
            echo -e "${YELLOW}Please verify:${NC}"
            echo "  - SSH alias '$BASH_ALIAS' is configured correctly"
            echo "  - The machine is reachable at $LOCAL_IP"
            echo "  - SSH key authentication is set up"
        fi
    fi
fi

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Setup Complete!                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Machine added successfully:${NC} $MACHINE_NAME"
echo -e "${BLUE}Profile location:${NC} $MACHINE_DIR"
echo ""
echo -e "${BLUE}Files created:${NC}"
echo "  - claude-profile.json (machine profile for Claude)"
echo "  - user-responses.json (structured user input)"
echo "  - user-responses.md (human-readable responses)"
echo "  - readable-profile.md (human-readable profile)"
echo "  - audit-log.json (audit event log)"
echo "  - reports/ (directory for audit reports)"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review the machine profile in: $MACHINE_DIR/readable-profile.md"
if [ "$HAS_BASH_ALIAS" = "yes" ]; then
    echo "  2. Run a security audit: ./audit-machine.sh $MACHINE_NAME"
    echo "  3. Connect to machine: ssh $BASH_ALIAS"
else
    echo "  2. Set up SSH access to the machine"
    echo "  3. Run: ./add-machine.sh --edit $MACHINE_NAME (to add SSH alias)"
fi
echo ""
echo -e "${YELLOW}To edit this machine later, run:${NC}"
echo "  ./add-machine.sh --edit $MACHINE_NAME"
echo ""
