---
name: view-audit-report
description: Use when the user wants to read a security audit report for a machine.
---

# View Audit Report

Retrieve and display the latest (or a specific) audit report for a registered machine.

## When to use

- User wants to review audit findings
- Look up a specific past audit (by date)
- Export report for compliance documentation
- Share findings with colleagues

## Inputs to gather

- Machine name (required)
- Report timestamp (optional; ISO8601 format; defaults to latest)

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   MACHINE_DIR="$DATA_DIR/machines/<machine_name>"
   ```

2. If no timestamp is specified, resolve the latest report:
   ```bash
   REPORT=$(ls -t "$MACHINE_DIR/reports"/*/audit-report.md | head -1)
   ```

3. If timestamp is specified, locate it:
   ```bash
   REPORT="$MACHINE_DIR/reports/<timestamp>/audit-report.md"
   ```

4. Verify the file exists; if not, list available reports:
   ```bash
   ls "$MACHINE_DIR/reports"/
   ```

5. Read and display the markdown to the user.

## Output / side effects

- Markdown content of the report displayed
- No modifications to any files

## Safety / constraints

- Reports may contain sensitive findings (CVEs, credentials, hardening gaps); treat as confidential.
- If no reports exist for the machine, inform the user and suggest running an audit first.
