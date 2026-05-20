---
name: add-machine
description: Use when the user wants to register a new machine for security auditing.
---

# Add Machine

Register a new machine into the fleet for repeatable security auditing. Elicit the machine name, description, SSH address, privilege level, OS, and physical/cloud classification. The script will test SSH connectivity and optionally deploy a CLAUDE.md to the remote.

## When to use

- User wants to onboard a new target machine
- Initial setup of a machine profile for audit tracking

## Inputs to gather

- Machine name (kebab-case identifier, e.g., `prod-db-01`)
- Short description (what the machine is / who owns it)
- SSH alias or `user@host:port` (must already be in `~/.ssh/config` or reachable without a password prompt)
- Root access required? (yes/no; determines audit depth)
- Operating system (Linux, macOS, Windows, etc.)
- Machine type (physical, cloud, VM, container host, etc.)

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   REPO_BASE="$DATA_DIR"
   export REPO_BASE
   ```

2. Invoke `scripts/add-machine.sh` with environment variables:
   ```bash
   cd <security-auditor-plugin-root>
   bash scripts/add-machine.sh
   ```
   The script runs interactively. Either attach the user's terminal (for manual input) or pipe responses via heredoc if you have all values in advance.

3. The script creates the profile bundle under `$REPO_BASE/machines/<machine-name>/`:
   - `claude-profile.json` — machine metadata
   - `user-responses.json` — structured responses (parsed for re-runs)
   - `user-responses.md` — human-readable responses
   - `readable-profile.md` — summary card
   - Tests SSH connection to verify reachability
   - Optionally deploys `CLAUDE.md` to the remote

4. Confirm success with the user; display the created profile path.

## Output / side effects

- Machine profile created in `$SECURITY_AUDITOR_DATA_DIR/machines/<machine-name>/`
- SSH connectivity verified
- User can now run audits on this machine

## Safety / constraints

- **SSH key-based auth must already be set up.** Password prompts will hang or fail in non-interactive skill execution.
- The script runs with the privileges of the current user; root access on the target is optional but unlocks deeper audit checks.
- Storing machine credentials in plain text (via CLAUDE.md) carries risk — ensure the target machine's file permissions are tight.
