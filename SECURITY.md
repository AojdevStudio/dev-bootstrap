# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, use [GitHub's private vulnerability reporting](https://github.com/AojdevStudio/dev-bootstrap/security/advisories/new) to submit your report. You'll receive a response within 72 hours acknowledging the report, and a detailed follow-up within 7 days.

If private vulnerability reporting is unavailable, email **security@aojdevstudio.com** with:

- Description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Potential impact

## Supply Chain Trust Model

This project downloads and executes software on your machine. Every install source is **official and canonical**:

| Tool | Install Source | Verification |
|------|---------------|--------------|
| Git | `winget` (Microsoft) | `Git.Git` package ID |
| cURL | `winget` (Microsoft) | `cURL.cURL` package ID |
| fnm | `winget` (Microsoft) | `Schniz.fnm` package ID |
| uv | `astral.sh/uv/install.ps1` | [Astral official](https://docs.astral.sh/uv/getting-started/installation/) |
| Bun | `bun.sh/install.ps1` | [Bun official](https://bun.sh/docs/installation) |
| Claude Code | `claude.ai/install.ps1` | [Anthropic official](https://code.claude.com/docs/en/setup) |
| Codex CLI | `npm install -g @openai/codex` | [OpenAI official](https://developers.openai.com/codex/cli) |
| WSL | `wsl --install` | [Microsoft official](https://learn.microsoft.com/en-us/windows/wsl/install) |

**We do not use third-party mirrors, custom binaries, or unofficial package sources.**

All source URLs are documented inline in [`bootstrap.ps1`](bootstrap.ps1) for independent verification.

## What This Project Does NOT Do

- **No credential storage** — API keys for Claude Code and Codex CLI are handled by those tools' own auth flows, never by this script.
- **No telemetry** — The script does not phone home, track usage, or collect any data.
- **No persistent services** — Nothing runs in the background after installation completes.
- **No system modification beyond PATH** — The only system-level changes are PATH additions and a PowerShell profile snippet for fnm.

## Security Best Practices for Users

1. **Read the script before running it.** The entire installer is a single file: [`bootstrap.ps1`](bootstrap.ps1). It's 183 lines.
2. **Verify the URL.** The one-liner fetches from `raw.githubusercontent.com/AojdevStudio/dev-bootstrap/main/bootstrap.ps1`. Confirm you're pointed at the correct repository.
3. **Use `-SkipWSL`** if you don't need WSL and want to avoid admin elevation.
4. **Review your PowerShell profile** after installation. The script adds one snippet (fnm initialization), marked with `# ---- dev-bootstrap: fnm ----` for easy identification.

## Scope

This policy covers the `bootstrap.ps1` script and `wsl/setup.sh` helper. The tools installed by this script (Git, Node.js, Python, etc.) have their own security policies maintained by their respective organizations.
