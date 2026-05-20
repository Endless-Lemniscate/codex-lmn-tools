# Codex LMN Tools

A Codex marketplace for LMN-flavored infrastructure, operations, and security tools.

The marketplace exposes:

- `security-auditor@codex-lmn-tools`

The plugin source is pinned to `Endless-Lemniscate/Codex-Security-Auditor-Plugin` at commit `a824c7e5db1ebd919ed05a33d9f3697e8fe78b52`.

## Codex config

Public marketplace source:

```toml
[marketplaces.codex-lmn-tools]
source_type = "git"
source = "https://github.com/Endless-Lemniscate/codex-lmn-tools.git"

[plugins."security-auditor@codex-lmn-tools"]
enabled = true
```

For local development, point `source` at this checkout and use `source_type = "local"`.
