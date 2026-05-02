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
| GitHub CLI | `winget` (Microsoft) | `GitHub.cli` package ID |
| Windows Terminal | `winget` (Microsoft) | `Microsoft.WindowsTerminal` package ID |
| fnm | `winget` (Microsoft) | `Schniz.fnm` package ID |
| pnpm | Corepack (bundled with Node) | [Node.js Corepack docs](https://nodejs.org/api/corepack.html) |
| uv | `winget` (Microsoft) | `astral-sh.uv` package ID, [Astral official](https://docs.astral.sh/uv/getting-started/installation/) |
| Bun | `winget` (Microsoft) | `Oven-sh.Bun` package ID, [Bun official](https://bun.sh/docs/installation) |
| ripgrep | `winget` (Microsoft) | `BurntSushi.ripgrep.MSVC` package ID |
| fd | `winget` (Microsoft) | `sharkdp.fd` package ID |
| bat | `winget` (Microsoft) | `sharkdp.bat` package ID |
| jq | `winget` (Microsoft) | `jqlang.jq` package ID |
| fzf | `winget` (Microsoft) | `junegunn.fzf` package ID |
| lazygit | `winget` (Microsoft) | `JesseDuffield.lazygit` package ID |
| yazi | `winget` (Microsoft) | `sxyazi.yazi` package ID |
| PowerToys | `winget` (Microsoft) | `Microsoft.PowerToys` package ID |
| Claude Code | Anthropic native installer | `irm https://claude.ai/install.ps1 \| iex`, [Anthropic official](https://code.claude.com/docs/en/setup) |
| Codex CLI | `npm install -g @openai/codex@latest` | [OpenAI official](https://developers.openai.com/codex/cli) |
| WSL | `wsl --install` | [Microsoft official](https://learn.microsoft.com/en-us/windows/wsl/install) |
| Docker Desktop | `winget` (Microsoft) | `Docker.DockerDesktop` package ID, [Docker official](https://docs.docker.com/desktop/setup/install/windows-install/) |

**We do not use third-party mirrors, custom binaries, or unofficial package sources.**

All source URLs are documented inline in [`bootstrap.ps1`](bootstrap.ps1) for independent verification.

## What This Project Does NOT Do

- **No credential storage** — API keys for Claude Code, Codex CLI, Docker, and GitHub are handled by those tools' own auth flows, never by this script.
- **No project telemetry** — The bootstrap script does not add analytics, phone-home behavior, or tracking.
- **No project-owned background services** — Docker Desktop and WSL install their own system components when selected; this project does not add custom services.

## Security Best Practices for Users

1. **Read the script before running it.** The entire installer is a single file: [`bootstrap.ps1`](bootstrap.ps1).
2. **Verify the URL.** The one-liner fetches from `raw.githubusercontent.com/AojdevStudio/dev-bootstrap/main/bootstrap.ps1`. Confirm you're pointed at the correct repository.
3. **Use `-SkipWSL`** if you don't need WSL or Docker Desktop and want to avoid that admin-heavy path.
4. **Review your PowerShell profile** after installation. The script adds one snippet (fnm initialization), marked with `# ---- dev-bootstrap: fnm ----` for easy identification.
5. **Review Docker Desktop licensing** before commercial use. Larger enterprises may need a paid Docker subscription.

## Scope

This policy covers the `bootstrap.ps1` script and `wsl/setup.sh` helper. The tools installed by this script (Git, Node.js, Python, etc.) have their own security policies maintained by their respective organizations.
