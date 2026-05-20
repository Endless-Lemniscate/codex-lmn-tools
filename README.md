# Codex LMN Tools

A Codex marketplace for LMN-flavored infrastructure, operations, and security tools.

The marketplace exposes:

- `security-auditor@codex-lmn-tools`

The `security-auditor` plugin is bundled in this repository at `plugins/security-auditor`, so Codex can read the plugin manifest and interface metadata directly from the marketplace checkout.

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
