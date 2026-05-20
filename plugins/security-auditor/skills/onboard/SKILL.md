---
name: onboard
description: Use when the user wants to set up the security-auditor plugin for the first time.
---

# Onboard

First-run setup for the security-auditor plugin. Verifies dependencies, creates the data directory, explains SSH requirements, and optionally scaffolds a placeholder machine.

## When to use

- User is setting up the plugin for the first time
- Migrating from a previous audit system
- Verifying the plugin is ready to use

## Inputs to gather

- None required, but optionally offer to scaffold a test machine afterward

## Procedure

1. Check system dependencies:
   ```bash
   for cmd in ssh scp python3; do
     which "$cmd" > /dev/null || { echo "$cmd not found"; exit 1; }
   done
   ```
   Fail with clear instructions if any dependency is missing.

2. Resolve and create the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   mkdir -p "$DATA_DIR/machines" "$DATA_DIR/.trash"
   echo "Data directory: $DATA_DIR"
   ```

3. Explain the SSH requirement:
   > This plugin audits remote machines over SSH. All target machines must be reachable via SSH without password prompts. Set up SSH keys in ~/.ssh/config or your system's SSH agent before adding machines.

4. Verify `~/.ssh/config` exists and is readable:
   ```bash
   [ -r ~/.ssh/config ] && echo "SSH config found" || echo "Warning: no SSH config"
   ```

5. Offer to scaffold a placeholder test machine (optional):
   ```bash
   Read "Would you like to add your first machine now? (y/n)"
   # If yes, invoke add-machine skill
   ```

6. Display the data directory path and confirm readiness.

## Output / side effects

- Data directory created at `$SECURITY_AUDITOR_DATA_DIR/`
- Dependencies verified
- SSH setup instructions displayed
- Optional: first machine registered if user accepts

## Safety / constraints

- SSH key-based auth is required; password-based SSH will fail in automated audits.
- The user is responsible for ensuring target machines allow SSH access.
- Data directory permissions should be restricted to the user (mode 0700).
