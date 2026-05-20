---
name: edit-machine
description: Use when the user wants to update an existing machine's profile or metadata.
---

# Edit Machine

Update an existing machine profile — change description, SSH address, privilege level, or type classification without re-running the full registration.

## When to use

- Machine moved to a new address
- User gained or lost root access
- Profile metadata needs correction
- Machine role changed (e.g., decommissioned vs. active)

## Inputs to gather

- Machine name (must already be registered)
- Field to change: description, ssh_address, root_access, os, machine_type, or status

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   REPO_BASE="$DATA_DIR"
   export REPO_BASE
   ```

2. Invoke the edit mode:
   ```bash
   cd <security-auditor-plugin-root>
   bash scripts/add-machine.sh --edit <machine_name>
   ```

3. The script re-prompts for each field, pre-filling current values. User selects which to change.

4. Updated profile is written back to `claude-profile.json`, `user-responses.json`, and `readable-profile.md`.

## Output / side effects

- Updated profile in `$SECURITY_AUDITOR_DATA_DIR/machines/<machine-name>/`
- SSH connection re-tested if address changed
- Previous audit reports remain untouched

## Safety / constraints

- Editing SSH address without verifying connectivity first can lock out future audits.
- Changing root_access to false may reduce audit coverage; confirm with the user.
