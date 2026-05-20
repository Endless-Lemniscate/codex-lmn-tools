---
name: audit-all
description: Use when the user wants to audit every registered machine in one pass.
---

# Audit All

Run security audits across the entire fleet in sequence. Produces a summary table showing which machines passed/failed and high-level findings per machine.

## When to use

- Periodic fleet-wide compliance sweep (weekly, monthly)
- Baseline security posture assessment
- Post-incident audit of all assets

## Inputs to gather

- Audit depth (optional; `quick`, `full`, or `report-only`; default `full`)
- Confirmation: audit all machines? (Y/n) — to avoid accidental fleet scans

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   REPO_BASE="$DATA_DIR"
   export REPO_BASE
   ```

2. List all registered machines:
   ```bash
   cd <security-auditor-plugin-root>
   MACHINES=$(bash scripts/list-machines.sh --json | python3 -c 'import json,sys; print("\n".join(m.get("machine_name", "") for m in json.load(sys.stdin) if m.get("machine_name")))')
   ```

3. Loop over each machine and run the audit:
   ```bash
   for MACHINE in $MACHINES; do
     echo "Auditing $MACHINE..."
     bash scripts/audit-machine.sh "$MACHINE" [--quick|--full|--report-only]
   done
   ```

4. Parse each report and collect results into a summary table (machine name, timestamp, critical/warning/pass count, overall status).

5. Display the table and note any machines that failed to audit (SSH down, permissions denied, etc.).

## Output / side effects

- All machines audited with fresh timestamped reports in their respective `reports/` directories
- Markdown summary table of pass/fail/findings per machine
- Machines that failed are flagged for investigation

## Safety / constraints

- Fleet-wide audits can take 30 minutes or more for large fleets; warn the user about duration.
- If one machine is unreachable, continue with the rest; don't halt the audit run.
- Summary should list which machines were skipped and why.
