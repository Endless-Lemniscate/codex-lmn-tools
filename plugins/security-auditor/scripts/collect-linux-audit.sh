#!/usr/bin/env bash

# Deterministic Linux security collector for Security Auditor.
# Runs on the target machine through SSH. Keep this script dependency-light:
# POSIX tools, bash, python3 when available, and optional npm/systemd/ss.

set +e

AUDIT_TYPE="${1:-full}"
MAX_PROJECTS="${SECURITY_AUDITOR_MAX_PROJECTS:-50}"
MAX_NPM_AUDITS="${SECURITY_AUDITOR_MAX_NPM_AUDITS:-12}"
DEV_PROCESS_RE='next dev|next-server|vite|webpack-dev-server|turbo.*dev|npm run dev|pnpm .*dev|yarn .*dev|bun .*dev|nodemon|ts-node-dev|flask run|django.*runserver|rails s|uvicorn .*--reload|gunicorn .*--reload|--inspect|9229'

section() {
    printf '\n## %s\n\n' "$1"
}

subsection() {
    printf '\n### %s\n\n' "$1"
}

code_block() {
    printf '```text\n'
    if [ -n "$1" ]; then
        printf '%s\n' "$1"
    else
        printf '(no output)\n'
    fi
    printf '```\n'
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

trim() {
    awk '{$1=$1; print}'
}

print_command_output() {
    title="$1"
    shift

    subsection "$title"
    output="$("$@" 2>&1)"
    code_block "$output"
}

extract_port() {
    printf '%s\n' "$1" | sed -E 's/.*:([0-9]+)$/\1/'
}

is_public_addr() {
    case "$1" in
        0.0.0.0:*|\*:*|:::*|[[]::*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_dev_port() {
    case "$1" in
        3000|3001|3002|3003|3004|3005|3333|4000|4173|5000|5173|5174|8000|8080|8888|9000|9229)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_sensitive_service_port() {
    case "$1" in
        21|23|25|110|143|389|445|465|587|993|995|1433|1521|2375|2376|3306|3389|5432|5433|5672|5900|5984|6379|6443|9200|9300|11211|15672|27017|27018)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ps_for_pid() {
    pid="$1"
    if [ -n "$pid" ]; then
        ps -p "$pid" -o user=,pid=,ppid=,etime=,args= 2>/dev/null
    fi
}

print_host_context() {
    section "Host context"
    {
        echo "Generated: $(date -Is 2>/dev/null || date)"
        echo "Hostname: $(hostname 2>/dev/null)"
        echo "User: $(id 2>/dev/null)"
        if [ -r /etc/os-release ]; then
            . /etc/os-release
            echo "OS: ${PRETTY_NAME:-unknown}"
        fi
        echo "Kernel: $(uname -a 2>/dev/null)"
        echo "Audit type: $AUDIT_TYPE"
    } | sed 's/^/- /'
}

print_update_status() {
    section "System update status"

    if command_exists apt; then
        subsection "APT upgradable packages"
        output="$(apt list --upgradable 2>/dev/null | tail -n +2 | head -80)"
        code_block "$output"

        subsection "APT security upgrade simulation"
        if command_exists apt-get; then
            output="$(apt-get -s upgrade 2>/dev/null | grep -Ei '^(Inst|Conf).*(security|ubuntu[/-]security|debian-security)' | head -80)"
            code_block "$output"
        else
            code_block "apt-get not found"
        fi
    elif command_exists dnf; then
        print_command_output "DNF security updates" dnf updateinfo list security
    elif command_exists yum; then
        print_command_output "YUM security updates" yum updateinfo list security
    else
        echo "- No supported package manager found for update checks."
    fi
}

print_runtime_exposure() {
    section "Runtime exposure and public listener rules"

    if ! command_exists ss; then
        subsection "Listening sockets"
        output="$(netstat -tulpn 2>/dev/null)"
        code_block "$output"
        echo "- ss not found; risk classification is limited."
        return
    fi

    listeners="$(ss -H -lntup 2>/dev/null)"
    subsection "Listening sockets"
    code_block "$listeners"

    subsection "Public dev/runtime findings"
    found="0"

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        local_addr="$(printf '%s\n' "$line" | awk '{print $5}')"
        port="$(extract_port "$local_addr")"
        pid="$(printf '%s\n' "$line" | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' | head -1)"
        proc_line="$(ps_for_pid "$pid")"
        proc_user="$(printf '%s\n' "$proc_line" | awk '{print $1}')"
        combined="$line $proc_line"

        if is_public_addr "$local_addr"; then
            if printf '%s\n' "$combined" | grep -Eiq "$DEV_PROCESS_RE"; then
                found="1"
                echo "- CRITICAL: public dev/runtime listener detected."
                echo "  local: $local_addr"
                echo "  process: $(printf '%s\n' "$proc_line" | trim)"
                if [ "$proc_user" = "root" ]; then
                    echo "  reason: dev server is bound to a public interface and runs as root."
                else
                    echo "  reason: dev server is bound to a public interface."
                fi
                echo ""
            elif is_dev_port "$port"; then
                found="1"
                echo "- HIGH: public listener on common dev/admin port $port."
                echo "  local: $local_addr"
                echo "  process: $(printf '%s\n' "$proc_line" | trim)"
                echo ""
            elif is_sensitive_service_port "$port"; then
                found="1"
                echo "- HIGH: public listener on sensitive service port $port."
                echo "  local: $local_addr"
                echo "  process: $(printf '%s\n' "$proc_line" | trim)"
                echo "  reason: databases, caches, Docker APIs, mail, or admin services should normally be private or explicitly firewalled."
                echo ""
            fi
        fi

        if [ "$proc_user" = "root" ] && printf '%s\n' "$combined" | grep -Eiq "$DEV_PROCESS_RE"; then
            found="1"
            echo "- HIGH: web/dev process runs as root."
            echo "  local: $local_addr"
            echo "  process: $(printf '%s\n' "$proc_line" | trim)"
            echo ""
        fi
    done << EOF
$listeners
EOF

    if [ "$found" = "0" ]; then
        echo "- No public dev/runtime listener matched the built-in high-risk rules."
    fi
}

print_node_project_inventory() {
    section "Node.js project inventory"

    if ! command_exists python3; then
        echo "- python3 not found; skipping package.json inventory."
        return
    fi

    SECURITY_AUDITOR_MAX_PROJECTS="$MAX_PROJECTS" python3 <<'PY'
import json
import os
import re

roots = ["/opt", "/srv", "/var/www", "/home", "/root"]
skip_dirs = {
    ".git", ".hg", ".svn", "node_modules", ".next", "dist", "build",
    "coverage", ".cache", ".turbo", "vendor", "target"
}
interesting_deps = {
    "next", "vite", "webpack-dev-server", "express", "fastify",
    "@nestjs/core", "react-server-dom-webpack"
}
max_projects = int(os.environ.get("SECURITY_AUDITOR_MAX_PROJECTS", "50"))
projects = []

def rel_depth(root, path):
    rel = os.path.relpath(path, root)
    if rel == ".":
        return 0
    return rel.count(os.sep) + 1

for root in roots:
    if not os.path.isdir(root):
        continue
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d for d in dirnames
            if d not in skip_dirs and not d.startswith(".")
        ]
        if rel_depth(root, dirpath) > 6:
            dirnames[:] = []
            continue
        if "package.json" not in filenames:
            continue
        package_path = os.path.join(dirpath, "package.json")
        try:
            with open(package_path, "r", encoding="utf-8") as f:
                pkg = json.load(f)
        except Exception as exc:
            projects.append((dirpath, f"unreadable package.json: {exc}"))
            continue

        deps = {}
        for key in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies"):
            value = pkg.get(key)
            if isinstance(value, dict):
                deps.update(value)
        scripts = pkg.get("scripts") if isinstance(pkg.get("scripts"), dict) else {}

        dep_hits = sorted(name for name in interesting_deps if name in deps)
        dev_scripts = {
            name: value for name, value in scripts.items()
            if re.search(r"(next dev|vite|webpack-dev-server|nodemon|ts-node-dev|--inspect|runserver|uvicorn .*--reload)", str(value), re.I)
        }

        lock_next_version = None
        lock_path = os.path.join(dirpath, "package-lock.json")
        if os.path.exists(lock_path):
            try:
                with open(lock_path, "r", encoding="utf-8") as f:
                    lock = json.load(f)
                package_entry = lock.get("packages", {}).get("node_modules/next")
                if isinstance(package_entry, dict):
                    lock_next_version = package_entry.get("version")
            except Exception:
                lock_next_version = "unreadable"

        if dep_hits or dev_scripts or lock_next_version:
            detail = {
                "path": dirpath,
                "name": pkg.get("name", ""),
                "dependencies": {name: deps.get(name) for name in dep_hits},
                "dev_scripts": dev_scripts,
                "lock_next_version": lock_next_version,
                "has_package_lock": os.path.exists(lock_path),
            }
            projects.append((dirpath, detail))
        if len(projects) >= max_projects:
            break
    if len(projects) >= max_projects:
        break

if not projects:
    print("- No interesting Node.js web projects found under /opt, /srv, /var/www, /home, /root.")
else:
    for _, detail in projects:
        if isinstance(detail, str):
            print(f"- {detail}")
            continue
        print(f"- Project: {detail['path']}")
        if detail["name"]:
            print(f"  name: {detail['name']}")
        if detail["dependencies"]:
            print(f"  web dependencies: {detail['dependencies']}")
        if detail["lock_next_version"]:
            print(f"  package-lock Next.js version: {detail['lock_next_version']}")
        if detail["dev_scripts"]:
            print(f"  dev/debug scripts: {detail['dev_scripts']}")
        print(f"  package-lock: {'yes' if detail['has_package_lock'] else 'no'}")
PY
}

print_npm_audit() {
    section "npm advisory audit"

    if [ "$AUDIT_TYPE" = "quick" ]; then
        echo "- Skipped in quick mode."
        return
    fi
    if ! command_exists npm; then
        echo "- npm not found; skipping npm audit."
        return
    fi
    if ! command_exists python3; then
        echo "- python3 not found; skipping npm audit parsing."
        return
    fi

    project_list="$(SECURITY_AUDITOR_MAX_PROJECTS="$MAX_NPM_AUDITS" python3 <<'PY'
import os

roots = ["/opt", "/srv", "/var/www", "/home", "/root"]
skip_dirs = {".git", "node_modules", ".next", "dist", "build", "coverage", ".cache", ".turbo", "vendor", "target"}
limit = int(os.environ.get("SECURITY_AUDITOR_MAX_PROJECTS", "12"))
found = []

def rel_depth(root, path):
    rel = os.path.relpath(path, root)
    if rel == ".":
        return 0
    return rel.count(os.sep) + 1

for root in roots:
    if not os.path.isdir(root):
        continue
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs and not d.startswith(".")]
        if rel_depth(root, dirpath) > 6:
            dirnames[:] = []
            continue
        if "package-lock.json" in filenames and "package.json" in filenames:
            found.append(dirpath)
            if len(found) >= limit:
                break
    if len(found) >= limit:
        break

for path in found:
    print(path)
PY
)"

    if [ -z "$project_list" ]; then
        echo "- No npm package-lock projects found in scan roots."
        return
    fi

    printf '%s\n' "$project_list" | while IFS= read -r project; do
        [ -z "$project" ] && continue
        subsection "npm audit: $project"
        audit_json="$(mktemp 2>/dev/null || printf '/tmp/security-auditor-npm-audit.json')"
        audit_err="$(mktemp 2>/dev/null || printf '/tmp/security-auditor-npm-audit.err')"

        if command_exists timeout; then
            (cd "$project" && timeout 90 npm audit --json > "$audit_json" 2> "$audit_err")
        else
            (cd "$project" && npm audit --json > "$audit_json" 2> "$audit_err")
        fi
        status="$?"

        python3 - "$audit_json" "$audit_err" "$status" <<'PY'
import json
import os
import sys

audit_path, err_path, status = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(audit_path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as exc:
    print(f"- npm audit did not return parseable JSON; exit={status}; error={exc}")
    try:
        with open(err_path, "r", encoding="utf-8") as f:
            err = f.read().strip()
        if err:
            print(err[:2000])
    except Exception:
        pass
    sys.exit(0)

metadata = data.get("metadata", {})
counts = metadata.get("vulnerabilities", {})
print(f"- exit: {status}")
print(f"- vulnerability counts: {counts}")

vulns = data.get("vulnerabilities", {})
interesting = []
for name, vuln in vulns.items():
    sev = str(vuln.get("severity", "")).lower()
    if sev in {"critical", "high"} or name in {"next", "vite", "webpack-dev-server", "react-server-dom-webpack", "express"}:
        titles = []
        for via in vuln.get("via", []):
            if isinstance(via, dict):
                title = via.get("title") or via.get("source") or via.get("url")
                if title:
                    titles.append(str(title))
        interesting.append({
            "name": name,
            "severity": vuln.get("severity"),
            "range": vuln.get("range"),
            "fix_available": vuln.get("fixAvailable"),
            "titles": titles[:5],
        })

if interesting:
    print("- high-signal advisories:")
    for item in interesting[:30]:
        print(f"  - {item['name']}: severity={item['severity']}, range={item['range']}, fix={item['fix_available']}")
        for title in item["titles"]:
            print(f"    - {title}")
else:
    print("- no high/critical or watched web-framework advisories in npm audit output.")
PY
        rm -f "$audit_json" "$audit_err"
    done
}

print_suspicious_runtime() {
    section "Suspicious process and outbound connection checks"

    subsection "Processes with deleted executables, tmp/dev-shm cwd/exe, or bot-like command lines"
    found="0"
    for proc in /proc/[0-9]*; do
        [ -d "$proc" ] || continue
        pid="${proc##*/}"
        exe="$(readlink "$proc/exe" 2>/dev/null)"
        cwd="$(readlink "$proc/cwd" 2>/dev/null)"
        cmd="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null)"
        path_marker="$exe $cwd"
        cmd_marker="$cmd"
        if printf '%s\n' "$path_marker" | grep -Eiq '(\(deleted\)|/tmp/|/dev/shm/)' ||
            printf '%s\n' "$cmd_marker" | grep -Eiq '(t\.me/|xmrig|kinsing|mirai|\.x86_64|wget http|curl http|busybox)'; then
            found="1"
            user="$(ps -p "$pid" -o user= 2>/dev/null | trim)"
            echo "- Suspicious process:"
            echo "  user: $user"
            echo "  pid: $pid"
            echo "  exe: ${exe:-unknown}"
            echo "  cwd: ${cwd:-unknown}"
            echo "  cmd: ${cmd:-unknown}"
            echo ""
        fi
    done
    if [ "$found" = "0" ]; then
        echo "- No obvious suspicious process matched the built-in rules."
    fi

    subsection "Established outbound TCP/UDP sessions"
    if command_exists ss; then
        output="$(ss -H -tunp state established 2>/dev/null | head -200)"
        code_block "$output"
    else
        code_block "ss not found"
    fi
}

print_persistence_checks() {
    section "Persistence and scheduled execution"

    subsection "Risky commands in systemd unit files"
    output="$(grep -RInE '(/tmp/|/dev/shm|wget |curl |nc |ncat |bash -c|sh -c|next dev|npm run dev|pnpm .*dev|yarn .*dev)' /etc/systemd/system /lib/systemd/system 2>/dev/null | head -120)"
    code_block "$output"

    subsection "Cron entries"
    {
        echo "# root crontab"
        crontab -l 2>/dev/null
        echo ""
        echo "# /etc/cron* files"
        grep -RInE '(/tmp/|/dev/shm|wget |curl |nc |ncat |bash -c|sh -c)' /etc/cron* 2>/dev/null | head -120
    } | sed '/^$/N;/^\n$/D' > /tmp/security-auditor-cron.$$ 2>/dev/null
    code_block "$(cat /tmp/security-auditor-cron.$$ 2>/dev/null)"
    rm -f /tmp/security-auditor-cron.$$

    subsection "SSH authorized_keys inventory"
    output="$(find /root /home -maxdepth 3 -name authorized_keys -type f -print -exec ls -l {} \; -exec sed -n '1,20p' {} \; 2>/dev/null)"
    code_block "$output"
}

print_users_and_permissions() {
    section "Users, privileges, and risky permissions"

    subsection "Interactive users"
    output="$(awk -F: '$7 !~ /(nologin|false)$/ {print $1 ":" $3 ":" $6 ":" $7}' /etc/passwd 2>/dev/null)"
    code_block "$output"

    subsection "sudo/admin groups"
    output="$(getent group sudo wheel admin 2>/dev/null)"
    code_block "$output"

    subsection "World-writable files on root filesystem sample"
    output="$(find / -xdev -type f -perm -0002 2>/dev/null | head -40)"
    code_block "$output"

    subsection "SUID binaries sample"
    output="$(find / -xdev -type f -perm -4000 2>/dev/null | head -60)"
    code_block "$output"
}

print_firewall_and_hardening() {
    section "Firewall, SSH, and hardening tools"

    subsection "Firewall status"
    if command_exists ufw; then
        code_block "$(ufw status verbose 2>&1)"
    elif command_exists firewall-cmd; then
        code_block "$(firewall-cmd --list-all 2>&1)"
    elif command_exists nft; then
        code_block "$(nft list ruleset 2>&1 | head -200)"
    elif command_exists iptables; then
        code_block "$(iptables -S 2>&1 | head -200)"
    else
        code_block "No supported firewall command found."
    fi

    subsection "SSH daemon effective config"
    if command_exists sshd; then
        code_block "$(sshd -T 2>/dev/null | grep -Ei '^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers|allowgroups|x11forwarding|permituserenvironment|authorizedkeysfile)' | sort)"
    else
        code_block "sshd command not found."
    fi

    subsection "Hardening tools"
    {
        for tool in fail2ban-client rkhunter chkrootkit clamscan auditctl; do
            if command_exists "$tool"; then
                echo "- $tool: installed"
            else
                echo "- $tool: not installed"
            fi
        done
        if command_exists fail2ban-client; then
            echo ""
            fail2ban-client status 2>/dev/null
        fi
    } > /tmp/security-auditor-hardening.$$ 2>/dev/null
    code_block "$(cat /tmp/security-auditor-hardening.$$ 2>/dev/null)"
    rm -f /tmp/security-auditor-hardening.$$
}

print_alert_summary() {
    section "High-signal alert coverage"
    cat <<'EOF'
- Public dev/runtime listeners are flagged when common dev commands or ports bind to 0.0.0.0, *, or [::].
- Public sensitive service ports are flagged for databases, caches, Docker APIs, mail, and remote admin services.
- Root-owned web/dev processes are flagged because an app RCE becomes host/root compromise.
- Node projects are inventoried from package.json and package-lock.json under common deployment roots.
- npm audit is run in full mode for package-lock projects to pull current npm advisory data.
- Suspicious processes are flagged when executables are deleted, cwd/exe is under /tmp or /dev/shm, or command lines match common bot/miner/downloader markers.
- Established outbound sessions are captured for C2 review.
- systemd, cron, and authorized_keys are checked for persistence indicators.
EOF
}

echo "# Security Audit Report"
print_host_context
print_alert_summary
print_runtime_exposure
print_node_project_inventory
print_npm_audit
print_suspicious_runtime
print_update_status
print_persistence_checks
print_users_and_permissions
print_firewall_and_hardening
