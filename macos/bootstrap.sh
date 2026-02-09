#!/usr/bin/env bash
set -euo pipefail

# macOS bootstrap entrypoint
# Installs: Xcode CLT, Homebrew, git, curl, fnm (Node), uv (Python), bun, Claude Code, Codex CLI

MARKER_BEGIN="# ---- dev-bootstrap (macos) ----"
MARKER_END="# ------------------------------"

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
  # Usage: ensure_line_in_file_once <file> <line>
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqs "$line" "$file"; then
    printf "\n%s\n" "$line" >> "$file"
  fi
}

ensure_snippet_in_zshrc_once() {
  local zshrc="$HOME/.zshrc"
  local snippet_file="$1"

  touch "$zshrc"

  if grep -Fqs "$MARKER_BEGIN" "$zshrc"; then
    return 0
  fi

  {
    echo
    echo "$MARKER_BEGIN"
    cat "$snippet_file"
    echo "$MARKER_END"
  } >> "$zshrc"
}

log "Preflight: Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools not found. Triggering install..."
  xcode-select --install || true
  echo "Waiting for Command Line Tools installation to complete..."
  # Poll until installed (user must complete GUI prompt)
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
fi

log "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Initialize brew in future shells (idempotent)
if [[ -x /opt/homebrew/bin/brew ]]; then
  ensure_line_in_file_once "$HOME/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  ensure_line_in_file_once "$HOME/.zprofile" 'eval "$(/usr/local/bin/brew shellenv)"'
  eval "$(/usr/local/bin/brew shellenv)"
else
  # If brew is installed somewhere else, just require it and continue.
  require_cmd brew
fi

log "Base tools (git, curl)"
# Idempotent: brew will verify or install.
brew list git >/dev/null 2>&1 || brew install git
brew list curl >/dev/null 2>&1 || brew install curl

log "Node via fnm"
brew list fnm >/dev/null 2>&1 || brew install fnm

# Ensure fnm activation + PATH in zsh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SNIPPET="$REPO_ROOT/macos/zshrc.snippet.sh"
require_cmd fnm
ensure_snippet_in_zshrc_once "$SNIPPET"

# Activate fnm in current shell
# shellcheck disable=SC2046
if fnm env --use-on-cd >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

fnm install --lts
fnm default lts-latest
require_cmd node
require_cmd npm
node -v
npm -v

log "Python via uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Ensure PATH contains uv default install location
# (actual PATH injection is handled by zsh snippet as well)
require_cmd uv
uv --version
uv python install 3.12
uv python pin 3.12
require_cmd python
python --version

log "Bun"
if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL https://bun.com/install | bash
fi
require_cmd bun
bun --version

log "Claude Code"
if ! command -v claude >/dev/null 2>&1; then
  # Per official docs for macOS/Linux
  curl -fsSL https://claude.ai/install.sh | bash
fi
if command -v claude >/dev/null 2>&1; then
  claude --version || true
else
  echo "Claude Code installed, but 'claude' is not on PATH yet. Open a new terminal and try: claude --version" >&2
fi

log "Codex CLI"
# Requires npm from the fnm-managed node.
npm list -g --depth=0 @openai/codex >/dev/null 2>&1 || npm install -g @openai/codex
require_cmd codex
codex --version

log "Finish"
echo "Open a NEW terminal so .zprofile/.zshrc changes load."
echo "Then run (interactive auth):"
echo " - claude"
echo " - codex"
