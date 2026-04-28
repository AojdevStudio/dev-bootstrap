#!/usr/bin/env bash
set -euo pipefail

# Linux server bootstrap (Ubuntu 24.04 LTS).
#
# Installs the same dev tool inventory as the Windows / macOS / WSL siblings,
# adapted for native Ubuntu server (no GUI). Idempotent — safe to re-run.
#
# Canonical sources:
# - fnm:        https://github.com/Schniz/fnm
# - uv:         https://docs.astral.sh/uv/
# - Bun:        https://bun.sh
# - Claude Code: https://code.claude.com/docs/en/setup
# - Codex CLI:  https://developers.openai.com/codex/cli
# - GitHub CLI: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
# - Tailscale:  https://tailscale.com/kb/1031/install-linux
# - cloudflared: https://pkg.cloudflare.com/index.html
# - yazi:       https://github.com/sxyazi/yazi/releases
#
# Run as a regular user with sudo. The script never authenticates Claude,
# Codex, Tailscale, or cloudflared — those are per-instance steps after the
# template is cloned.

# -------------------- helpers --------------------

MARKER_BEGIN="# ---- dev-bootstrap (linux) ----"
MARKER_END="# --------------------------------"

log() {
  printf "\n== %s ==\n" "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    return 1
  }
}

ensure_line_in_file_once() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqs "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
  fi
}

ensure_block_in_file_once() {
  # Wrap a multi-line block in markers so re-runs upgrade in place rather
  # than appending duplicates.
  local file="$1" block="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fqs "$MARKER_BEGIN" "$file"; then
    return 0
  fi
  {
    echo
    echo "$MARKER_BEGIN"
    printf "%s\n" "$block"
    echo "$MARKER_END"
  } >> "$file"
}

apt_install_if_missing() {
  # Install only packages that aren't already present, to keep re-runs quiet
  # and avoid the long apt status output for already-installed packages.
  local missing=()
  for pkg in "$@"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      missing+=("$pkg")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    sudo apt-get install -y "${missing[@]}"
  fi
}

# -------------------- preflight --------------------

log "Preflight"

if [[ $EUID -eq 0 ]]; then
  echo "Run as a non-root user with sudo. The provisioner creates 'ossie'." >&2
  exit 1
fi

require_cmd sudo
sudo -v

# Universe is required for lazygit and a few other tools on cloud images.
if ! grep -Eq '^[^#]*\s+universe(\s|$)' /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
  sudo add-apt-repository -y universe || true
fi

sudo apt-get update -y

# -------------------- base apt packages --------------------

log "Base packages (apt)"

apt_install_if_missing \
  ca-certificates curl wget git build-essential pkg-config \
  zsh tmux unzip xz-utils file \
  ripgrep fd-find bat jq fzf lazygit \
  software-properties-common gnupg lsb-release apt-transport-https

# Ubuntu packages fd as fdfind and bat as batcat to dodge name collisions
# with older tools. dev-bootstrap callers expect plain fd / bat names —
# create stable user-local symlinks (per-user, no PATH conflicts).
mkdir -p "$HOME/.local/bin"
[[ -e "$HOME/.local/bin/fd" ]] || ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
[[ -e "$HOME/.local/bin/bat" ]] || ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"

# -------------------- GitHub CLI (apt repo) --------------------

log "GitHub CLI (gh)"

if ! command -v gh >/dev/null 2>&1; then
  # Per https://github.com/cli/cli/blob/trunk/docs/install_linux.md
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y gh
fi

# -------------------- Tailscale (no auth) --------------------

log "Tailscale (installed, NOT authenticated)"

if ! command -v tailscale >/dev/null 2>&1; then
  # Per https://tailscale.com/kb/1031/install-linux
  curl -fsSL https://tailscale.com/install.sh | sh
fi
# Do NOT run `tailscale up` here — auth happens per-clone after template.

# -------------------- cloudflared (no auth) --------------------

log "cloudflared (installed, no tunnel registered)"

if ! command -v cloudflared >/dev/null 2>&1; then
  # Per https://pkg.cloudflare.com/index.html
  sudo mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y cloudflared
fi

# -------------------- fnm + Node LTS + Corepack pnpm --------------------

log "Node via fnm"

if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
  # https://github.com/Schniz/fnm — install to ~/.local/share/fnm, no shell edits
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell --install-dir "$HOME/.local/share/fnm"
fi

export PATH="$HOME/.local/share/fnm:$HOME/.local/bin:$PATH"
require_cmd fnm

eval "$(fnm env --use-on-cd --shell bash)"

# Idempotency: only call `fnm install --lts` if no Node is installed yet.
if ! fnm list 2>/dev/null | grep -Eq 'v[0-9]+\.[0-9]+\.[0-9]+'; then
  fnm install --lts
fi

LTS_CURRENT="$(fnm current 2>/dev/null || true)"
if [[ "$LTS_CURRENT" =~ ^v[0-9] ]]; then
  fnm default "$LTS_CURRENT" >/dev/null
else
  fnm default lts-latest >/dev/null 2>&1 || true
fi

require_cmd node
require_cmd npm
node --version
npm --version

# Corepack ships with Node ≥16.10 — use it for pnpm to track each project's
# packageManager field rather than colliding with a global npm install.
if command -v corepack >/dev/null 2>&1; then
  corepack enable pnpm >/dev/null 2>&1 || true
  corepack prepare pnpm@latest --activate >/dev/null 2>&1 || true
fi
pnpm --version 2>/dev/null || true

# -------------------- uv + Python 3.12 --------------------

log "Python via uv"

if ! command -v uv >/dev/null 2>&1; then
  # https://docs.astral.sh/uv/
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

export PATH="$HOME/.local/bin:$PATH"
require_cmd uv
uv --version

if ! uv python find 3.12 >/dev/null 2>&1; then
  uv python install 3.12
fi
uv python pin 3.12 >/dev/null
uv run python --version

# -------------------- Bun --------------------

log "Bun"

if ! command -v bun >/dev/null 2>&1 && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
  # https://bun.sh
  curl -fsSL https://bun.sh/install | bash
fi
export PATH="$HOME/.bun/bin:$PATH"
require_cmd bun
bun --version

# -------------------- yazi (GitHub release binary) --------------------

log "yazi (GitHub release binary)"

if ! command -v yazi >/dev/null 2>&1; then
  # Release binary avoids dragging the rust toolchain onto a server template.
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) YAZI_TRIPLE="x86_64-unknown-linux-gnu" ;;
    aarch64) YAZI_TRIPLE="aarch64-unknown-linux-gnu" ;;
    *) echo "Unsupported arch for yazi release: $ARCH" >&2; YAZI_TRIPLE="" ;;
  esac
  if [[ -n "$YAZI_TRIPLE" ]]; then
    YAZI_TMP="$(mktemp -d)"
    YAZI_LATEST_URL="$(curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest \
      | grep -oE "https://[^\"]+yazi-${YAZI_TRIPLE}\\.zip" | head -n1)"
    if [[ -n "$YAZI_LATEST_URL" ]]; then
      curl -fsSL -o "$YAZI_TMP/yazi.zip" "$YAZI_LATEST_URL"
      unzip -q "$YAZI_TMP/yazi.zip" -d "$YAZI_TMP"
      install -m 0755 "$YAZI_TMP"/yazi-*/yazi "$HOME/.local/bin/yazi"
      install -m 0755 "$YAZI_TMP"/yazi-*/ya "$HOME/.local/bin/ya" 2>/dev/null || true
      rm -rf "$YAZI_TMP"
    else
      echo "Could not resolve yazi release URL — skipping (re-run later)." >&2
    fi
  fi
fi
command -v yazi >/dev/null 2>&1 && yazi --version || true

# -------------------- Claude Code (no login) --------------------

log "Claude Code (installed, NOT authenticated)"

if ! command -v claude >/dev/null 2>&1; then
  # https://code.claude.com/docs/en/setup
  curl -fsSL https://claude.ai/install.sh | bash
fi
# Login is per-instance: run `claude login` after template clone.
command -v claude >/dev/null 2>&1 && claude --version || \
  echo "Claude Code installed; open a new shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""

# -------------------- Codex CLI (npm global) --------------------

log "Codex CLI"

if ! npm ls -g --depth=0 @openai/codex 2>/dev/null | grep -q '@openai/codex@'; then
  # https://developers.openai.com/codex/cli
  npm install -g @openai/codex
fi
require_cmd codex
codex --version

# -------------------- shell config (bash + zsh) --------------------

log "Shell config (bash + zsh PATH/fnm)"

read -r -d '' SHELL_BLOCK <<'EOF' || true
# PATH for dev-bootstrap user-local installs
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.bun/bin:$PATH"

# fnm activation (Node manager)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi
EOF

ensure_block_in_file_once "$HOME/.bashrc" "$SHELL_BLOCK"
ensure_block_in_file_once "$HOME/.zshrc" "$SHELL_BLOCK"

# -------------------- finish --------------------

log "Finish"

cat <<'EOF'
Installed. Open a new shell so PATH/profile changes load, then verify:

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

Per-instance auth (NOT done here — do this after VM clone):
  - sudo tailscale up --auth-key=<TS_AUTH_KEY> --ssh
  - cloudflared service install <TUNNEL_TOKEN>
  - claude login
  - codex login
EOF
