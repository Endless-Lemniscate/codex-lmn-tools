---
name: audit-machine
description: Use when the user wants to run a security audit on a registered machine.
---

# Audit Machine

Execute a security audit over SSH on a single registered machine. The audit checks for configuration drift, hardening gaps, policy compliance, application runtime exposure, package advisories, suspicious processes, outbound sessions, and persistence indicators. Output is timestamped and appended to the machine's audit log.

## When to use

- User wants to run a fresh security scan on a machine
- Periodic audit checkpoints before/after changes
- Compliance validation for a specific target

## Inputs to gather

- Machine name (required; must be registered)
- Audit depth (optional; `quick`, `full`, or `report-only`; default `full`)
  - `quick` — fast checks only (10–30 seconds)
  - `full` — comprehensive scan (5–15 minutes)
  - `report-only` — regenerate markdown from the most recent raw data

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   REPO_BASE="$DATA_DIR"
   export REPO_BASE
   ```

2. Verify the machine is registered:
   ```bash
   cd <security-auditor-plugin-root>
   bash scripts/list-machines.sh <machine_name> --json | python3 -m json.tool
   ```
   Fail gracefully if the machine is not found.

3. Invoke the audit:
   ```bash
   bash scripts/audit-machine.sh <machine_name> [--quick|--full|--report-only]
   ```

4. The script runs over SSH, writes `reports/<timestamp>/audit-report.md`, and updates `audit-log.json`. It always runs the deterministic Linux collector in `scripts/collect-linux-audit.sh`; when remote Claude Code is available, the collector is appended as evidence after the AI-generated report.

5. Extract the report path from the output and read the markdown for a brief summary. Treat these as urgent when present: public dev listeners, `next dev`/Vite/webpack/debug servers on `0.0.0.0` or `[::]`, root-owned web runtimes, high/critical `npm audit` advisories, deleted executables, `/tmp` or `/dev/shm` processes, and suspicious outbound sessions. Display path and key findings to the user.

## Output / side effects

- New timestamped report in `$SECURITY_AUDITOR_DATA_DIR/machines/<machine-name>/reports/<ISO8601-timestamp>/audit-report.md`
- `audit-log.json` updated with entry for this run
- Return the report path and a one-paragraph summary of critical findings

## Safety / constraints

- Audit may require root privileges on the target for comprehensive checks.
- Network latency and `npm audit` can affect runtime; full audits may take 10+ minutes on slow links or large Node fleets.
- The script reads system files on the target; ensure proper credentials and permissions.
