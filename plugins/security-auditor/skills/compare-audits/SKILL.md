---
name: compare-audits
description: Use when the user wants to compare two audits and see what changed.
---

# Compare Audits

Diff the two most recent audits for a machine (or two specific timestamps) and surface what changed: new findings, resolved issues, and unchanged items.

## When to use

- Review what security posture changed after a patching cycle
- Track remediation progress for a known issue
- Understand the impact of configuration changes
- Compliance trend analysis

## Inputs to gather

- Machine name (required)
- Two timestamps (optional; ISO8601 format; defaults to the two most recent reports)

## Procedure

1. Resolve the data directory:
   ```bash
   DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
   export SECURITY_AUDITOR_DATA_DIR="$DATA_DIR"
   MACHINE_DIR="$DATA_DIR/machines/<machine_name>"
   ```

2. If no timestamps are given, locate the two most recent reports:
   ```bash
   REPORTS=($(ls -t "$MACHINE_DIR/reports"/*/audit-report.md | head -2))
   REPORT_OLD="${REPORTS[1]}"
   REPORT_NEW="${REPORTS[0]}"
   ```

3. Read both reports and parse sections (findings, metadata, status).

4. Use text diffing and semantic analysis to identify:
   - **New findings** — present in the new report but not the old
   - **Resolved findings** — in the old report but not the new
   - **Unchanged findings** — present in both
   - **Status changes** — severity or category shifts

5. Generate a structured markdown delta document with three sections: New, Resolved, Unchanged. Include a summary count (e.g., "5 new findings, 2 resolved, 8 unchanged").

## Output / side effects

- Markdown delta document displayed to the user
- Optional: save delta to `$MACHINE_DIR/deltas/<timestamp>-diff.md` for record-keeping
- No modifications to audit reports themselves

## Safety / constraints

- Comparison relies on consistent report formatting; if reports are formatted inconsistently, diffs may be imprecise.
- Large diffs (50+ changes) should be summarized with a table of contents.
- Resolved findings should be flagged as "confirm resolution" — some may be reclassified rather than truly fixed.
