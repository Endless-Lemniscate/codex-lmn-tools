---
name: list-machines
description: Use when the user wants to view registered machines and their metadata.
---

# List Machines

Display all registered machines in the fleet with optional detailed views and live connectivity checks.

## When to use

- User wants a quick overview of the fleet
- Check SSH reachability of all machines
- Export machine inventory in JSON format
- Review detailed metadata for a single machine

## Inputs to gather

- Machine name (optional; if omitted, list all)
- View mode (optional):
  - `--detailed` — full profile metadata
  - `--status` — live SSH connectivity check (may take time)
  - `--json` — raw JSON output for scripting

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   REPO_BASE="$DATA_DIR"
   export REPO_BASE
   ```

2. Invoke the list script:
   ```bash
   cd <security-auditor-plugin-root>
   bash scripts/list-machines.sh [machine_name] [--detailed|--status|--json]
   ```

3. Format output as a table (default) or pass through JSON/detailed formats as-is.

4. If `--status` is requested, note that connectivity checks add time; show a spinner or progress indicator.

## Output / side effects

- Table or JSON of machines with name, description, SSH address, OS, type, and registration date
- Optional `--detailed` adds root_access status, last audit timestamp, audit report count
- Optional `--status` shows real-time SSH connectivity (reachable/unreachable)
- No files are modified

## Safety / constraints

- Status checks perform actual SSH connections; may fail if credentials have expired.
- Large fleets (50+ machines) may be slow in detailed or status modes.
