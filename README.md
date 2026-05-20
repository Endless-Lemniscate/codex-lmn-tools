# Codex LMN Tools

A Codex marketplace for LMN-flavored infrastructure, operations, and security tools.

The marketplace exposes:

- `security-auditor@codex-lmn-tools`

The plugin source is pinned to `Endless-Lemniscate/Codex-Security-Auditor-Plugin` at commit `63acbd4ac6c81cb0201cb61f4ea960eb96a69a20`.

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
