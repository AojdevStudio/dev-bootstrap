# dev-bootstrap (Linux)

Native Ubuntu server bootstrap. Installs the same dev tool inventory as the
Windows / macOS / WSL siblings, idempotently, with no GUI assumptions.

Target: **Ubuntu 24.04 LTS server**. Other Debian-family distros are likely
to work but are not tested.

## Install

Run as a regular user with sudo (the script refuses to run as root):

```bash
curl -fsSL https://raw.githubusercontent.com/AojdevStudio/dev-bootstrap/main/linux/bootstrap.sh | bash
```

Or clone the repo and run it directly:

```bash
git clone https://github.com/AojdevStudio/dev-bootstrap
./dev-bootstrap/linux/bootstrap.sh
```

Open a new shell when it finishes so PATH and shell-config changes take effect.

## What gets installed

| Tool | Source | Notes |
|------|--------|-------|
| **git, curl, wget, build-essential, ca-certificates** | apt | base build deps |
| **zsh, tmux, unzip, xz-utils** | apt | shell + archives |
| **ripgrep, fd-find, bat, jq, fzf** | apt | CLI essentials (`fd` / `bat` symlinked to plain names in `~/.local/bin`) |
| **lazygit** | apt (universe) | TUI for git |
| **GitHub CLI (`gh`)** | apt repo | added via official keyring + sources file |
| **Tailscale** | apt repo | installed only — not authenticated |
| **cloudflared** | apt repo | installed only — no tunnel registered |
| **fnm** | curl install | Node version manager, installed to `~/.local/share/fnm` |
| **Node.js LTS** | fnm | matches dev-bootstrap Windows/macOS path |
| **pnpm** | Corepack | tracks each project's `packageManager` field |
| **uv** | curl install | Astral Python toolchain |
| **Python 3.12** | uv | pinned via `uv python pin 3.12` |
| **Bun** | curl install | installed to `~/.bun` |
| **yazi** | GitHub release binary | TUI file manager (release binary, not cargo, to avoid pulling rust onto server templates) |
| **Claude Code** | `claude.ai/install.sh` | native binary; install only, no login |
| **Codex CLI** | npm global (`@openai/codex`) | install only, no login |

## What is NOT done

By design — these are per-instance steps:

- `tailscale up` (Tailscale auth)
- `cloudflared service install <TOKEN>` (tunnel registration)
- `claude login` (Anthropic auth — per-clone subscription session)
- `codex login` (OpenAI auth)
- Any `.env` files, API keys, or repo clones

This script is safe to bake into a VM golden template.

## Re-running

The script is idempotent. Every install gate checks for existing state first
(`dpkg-query`, `command -v`, `npm ls -g`, `fnm list`, etc.). Profile snippet
injection uses marker blocks so re-runs do not duplicate config.

## Verify

After a successful run (and a new shell):

```bash
node --version
npm --version
pnpm --version
uv run python --version
bun --version
rg --version
fd --version
bat --version
fzf --version
jq --version
lazygit --version
yazi --version
gh --version
tailscale version
cloudflared --version
claude --version
codex --version
```

## Troubleshooting

- **`fd` or `bat` not found** — Ubuntu packages them as `fdfind` / `batcat`.
  The script creates `~/.local/bin/fd` and `~/.local/bin/bat` symlinks; make
  sure `~/.local/bin` is on PATH (the shell snippet handles this).
- **`lazygit` not in apt** — your sources are missing the `universe`
  component. Re-run after `sudo add-apt-repository universe`.
- **`claude` not on PATH** — the `claude.ai/install.sh` installer puts it in
  `~/.local/bin`. Open a new shell or `export PATH="$HOME/.local/bin:$PATH"`.
- **yazi skipped** — release URL resolution failed (rate limit on the GitHub
  API or unsupported arch). Re-run later, or install via cargo if you have
  rust available.

## Related

- `bootstrap.ps1` — Windows entrypoint
- `macos/bootstrap.sh` — macOS entrypoint
- `wsl/setup.sh` — WSL2-side helper invoked by the Windows entrypoint
- `~/Projects/homelab/proxmox-templates/ubuntu-agent-base/` — Proxmox VM
  golden template that wraps this bootstrap with cloud-init + qemu-guest-agent
  + ufw/fail2ban/unattended-upgrades hardening
