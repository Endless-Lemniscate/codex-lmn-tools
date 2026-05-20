# Codex Security Auditor Plugin

A Codex plugin port of [`danielrosehill/Claude-Security-Auditor-Plugin`](https://github.com/danielrosehill/Claude-Security-Auditor-Plugin). It is a full copy of the original Claude plugin's fleet-auditing workflow, adapted to Codex plugin conventions.

The plugin manages a fleet of machines and runs repeatable security audits over SSH. Each machine gets a persistent profile and timestamped report history; audits can be compared across runs to surface drift.

## What it does

- Register machines with structured profiles: SSH address, OS, privilege level, purpose, and machine type.
- Run security audits over SSH using Claude Code on the remote machine when present, or fall back to direct shell checks.
- Always append deterministic SSH evidence for runtime exposure, dependency advisories, suspicious processes, outbound sessions, and persistence indicators.
- Persist timestamped audit reports per machine.
- Diff successive audits to highlight new findings, resolved issues, and configuration drift.
- List, edit, and remove machines from the audit fleet.

## Skills

| Skill | Purpose |
|---|---|
| `onboard` | First-run setup: verify dependencies, create the data directory, and explain SSH requirements. |
| `add-machine` | Register a new machine for auditing. |
| `edit-machine` | Update an existing machine's profile. |
| `list-machines` | List the fleet: brief, detailed, live status, or JSON. |
| `audit-machine` | Run a security audit on one registered machine. |
| `audit-all` | Audit every registered machine in one pass. |
| `view-audit-report` | Display the latest or specified audit report for a machine. |
| `compare-audits` | Diff two audits and surface new, resolved, and unchanged findings. |
| `remove-machine` | Deregister a machine and archive it to the trash directory. |

## Codex plugin layout

```text
.
├── .codex-plugin/plugin.json
├── skills/
│   ├── add-machine/SKILL.md
│   ├── audit-all/SKILL.md
│   ├── audit-machine/SKILL.md
│   ├── compare-audits/SKILL.md
│   ├── edit-machine/SKILL.md
│   ├── list-machines/SKILL.md
│   ├── onboard/SKILL.md
│   ├── remove-machine/SKILL.md
│   └── view-audit-report/SKILL.md
└── scripts/
    ├── add-machine.sh
    ├── audit-machine.sh
    └── list-machines.sh
```

## Installation

The plugin is bundled in the `codex-lmn-tools` marketplace:

```bash
git clone https://github.com/Endless-Lemniscate/codex-lmn-tools.git
cd codex-lmn-tools/plugins/security-auditor
```

Use `security-auditor@codex-lmn-tools` from the marketplace, or run the bundled scripts directly from this plugin directory.

For direct script use, run the bundled scripts from the repository root:

```bash
bash scripts/list-machines.sh
bash scripts/add-machine.sh
bash scripts/audit-machine.sh <machine-name>
```

## Requirements

- `bash` 4.0+
- `python3` 3.6+
- `ssh` and `scp`
- SSH key-based authentication to every machine you want to audit
- Optional on the remote machine: Claude Code, used for richer audits when present
- Optional on the remote machine: `npm`, used for `npm audit --json` on discovered package-lock projects

Password-based SSH prompts are not suitable for automated Codex execution. Set up SSH aliases in `~/.ssh/config` or make the target reachable without interactive prompts.

## Data storage

Machine profiles, audit reports, and the fleet log live under:

```bash
DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
```

Per-machine data lives under:

```text
$DATA_DIR/machines/<machine-name>/
```

Per-machine layout:

- `claude-profile.json` — structured profile
- `user-responses.json` / `user-responses.md` — original onboarding inputs
- `readable-profile.md` — human-readable narrative profile
- `audit-log.json` — timestamped event log
- `reports/<timestamp>/audit-report.md` — full audit report
- `reports/latest/` — symlink to the most recent report, when created

This data persists across plugin updates. To override storage, set `SECURITY_AUDITOR_DATA_DIR`.

## Audit coverage

The default audit checklist covers these domains:

1. Antivirus / endpoint protection presence and configuration
2. Automatic security update status
3. Rootkit / IOC detection tooling
4. File and directory permission posture
5. User account hygiene: sudo, idle accounts, password policy
6. Network exposure: firewall, open ports, listening services
7. Application runtime exposure: public dev listeners, debug ports, sensitive service ports, root-owned web runtimes
8. Node.js dependency exposure: `package.json`/`package-lock.json` inventory and `npm audit` advisories
9. Suspicious runtime indicators: deleted executables, `/tmp` or `/dev/shm` processes, outbound sessions
10. Persistence indicators: systemd, cron, and `authorized_keys`
11. Auxiliary hardening: fail2ban, SSH config, and related controls

The high-signal rules are designed to catch incidents like a public `next dev` or Vite server bound to `0.0.0.0`, especially when it runs as `root` and the project has vulnerable framework advisories. They also flag public database/cache/admin ports such as PostgreSQL, Redis, MongoDB, Elasticsearch, Docker API, and RDP.

The checklist is Linux-shaped. macOS and Windows targets may work with caveats and should be reviewed for false positives.

## Quick start

In Codex, use natural-language prompts rather than Claude slash commands:

1. `Use Security Auditor to onboard this plugin.`
2. `Use Security Auditor to add a machine for auditing.`
3. `Use Security Auditor to list registered machines.`
4. `Use Security Auditor to audit <machine-name>.`
5. `Use Security Auditor to view the latest report for <machine-name>.`
6. `Use Security Auditor to compare the two latest audits for <machine-name>.`

## Direct script examples

Create the data directory:

```bash
DATA_DIR="${SECURITY_AUDITOR_DATA_DIR:-${CODEX_USER_DATA:-${CLAUDE_USER_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-plugins}}/security-auditor/data}"
mkdir -p "$DATA_DIR/machines" "$DATA_DIR/.trash"
```

Add a machine interactively:

```bash
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/add-machine.sh
```

List machines:

```bash
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/list-machines.sh
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/list-machines.sh --detailed
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/list-machines.sh --json
```

Audit a machine:

```bash
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/audit-machine.sh <machine-name> --full
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/audit-machine.sh <machine-name> --quick
```

Tune heavier scans:

```bash
SECURITY_AUDITOR_MAX_PROJECTS=80 SECURITY_AUDITOR_MAX_NPM_AUDITS=20 \
  SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/audit-machine.sh <machine-name> --full
```

Show the latest saved report without re-auditing:

```bash
SECURITY_AUDITOR_DATA_DIR="$DATA_DIR" bash scripts/audit-machine.sh <machine-name> --report-only
```

## Differences from the Claude plugin

This repository intentionally keeps the original plugin behavior, but adapts the packaging and invocation surface for Codex:

- `.claude-plugin/plugin.json` became `.codex-plugin/plugin.json`.
- Claude slash commands became Codex skills in `skills/*/SKILL.md`.
- Hardcoded local paths from the original skill docs were replaced with Codex-friendly plugin-root instructions.
- Data storage can use `SECURITY_AUDITOR_DATA_DIR` or `CODEX_USER_DATA`.
- The bundled scripts remain shell-compatible and can still be used directly.

## Upstream

This is a Codex port of:

- Repository: [`danielrosehill/Claude-Security-Auditor-Plugin`](https://github.com/danielrosehill/Claude-Security-Auditor-Plugin)
- Source commit used for this port: `9db0efae3f0374da63b44c1c2034394705a91f28`
- License: MIT

## Status

Initial Codex port. The plugin contents mirror the upstream Claude plugin's skills and scripts, with Codex-compatible manifest, README, data-directory resolution, and small compatibility fixes for JSON output and report-only viewing.

## License

MIT — see [`LICENSE`](LICENSE).
