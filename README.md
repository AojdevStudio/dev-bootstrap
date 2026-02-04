# dev-bootstrap (Windows-first)

A Windows-first developer bootstrap repo.

## One-liner (PowerShell)
Run in **PowerShell** (Admin is required only for enabling WSL):

```powershell
irm https://raw.githubusercontent.com/Jarvis-AojDevStuio/dev-bootstrap/main/bootstrap.ps1 | iex
```

## What it installs
- Git (winget)
- cURL (winget)
- fnm (Node manager) + Node LTS + npm
- uv (Python toolchain) + Python 3.12 (pinned)
- bun
- Claude Code
- Codex CLI
- WSL2 + optional WSL-side setup (`wsl/setup.sh`)

## Flags
- `-SkipWSL` — skip WSL install + WSL-side setup

## Notes
- This repo is designed so **`bootstrap.ps1` is the only entrypoint**.
- Canonical sources are documented inline in `bootstrap.ps1`.

## Post-install
- Open a NEW PowerShell window so PATH/profile changes load.
- Verify installs: `node --version`, `npm --version`, `python --version`, `bun --version`.
- Authenticate tools as needed: `claude --version` (https://code.claude.com/docs/en/setup) and `codex --version` (https://developers.openai.com/codex/cli).
