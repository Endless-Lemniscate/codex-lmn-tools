---
name: remove-machine
description: Use when the user wants to deregister a machine from the fleet.
---

# Remove Machine

Deregister a machine from the fleet. The profile and audit reports are archived (not deleted) for compliance and historical reference.

## When to use

- Machine is decommissioned
- Machine is no longer under audit scope
- Consolidating redundant entries

## Inputs to gather

- Machine name (required)
- Confirmation: are you sure? (Y/n) — this is irreversible without manual recovery from trash

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   MACHINE_DIR="$DATA_DIR/machines/<machine_name>"
   TRASH_DIR="$DATA_DIR/.trash"
   ```

2. Verify the machine exists:
   ```bash
   [ -d "$MACHINE_DIR" ] || { echo "Machine not found"; exit 1; }
   ```

3. Prompt for confirmation. If the user declines, abort.

4. Archive the profile:
   ```bash
   mkdir -p "$TRASH_DIR"
   TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   mv "$MACHINE_DIR" "$TRASH_DIR/<machine_name>-$TIMESTAMP"
   ```

5. Confirm removal to the user and show the archive path.

## Output / side effects

- Machine profile and all audit reports moved to `$SECURITY_AUDITOR_DATA_DIR/.trash/<machine_name>-<timestamp>/`
- Machine no longer appears in fleet lists
- Archive can be manually restored if needed

## Safety / constraints

- This is destructive (removes active tracking). Always confirm with the user.
- Historical audit data is preserved in trash for compliance retention.
- Trash directory should be backed up before cleanup.
