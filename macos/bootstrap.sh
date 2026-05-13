#!/usr/bin/env bash
set -euo pipefail

# macOS bootstrap entrypoint
# Installs: Xcode CLT, Homebrew, git, curl, fnm or node@22 (per --brew-only),
#           uv (Python), bun, Claude Code, Codex CLI.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default flag state before parse_flags runs, so any helper that reads these
# globals stays safe under `set -u` even if parse_flags is reordered later.
BREW_ONLY=0
USE_FNM=1
FORCE_RELINK=0
RESTORE_GLOBALS_FILE=""

# shellcheck source=macos/lib/cli.sh
source "$SCRIPT_DIR/lib/cli.sh"
# shellcheck source=macos/lib/node-utils.sh
source "$SCRIPT_DIR/lib/node-utils.sh"

# parse_flags may exit 2 on --help; bubble that up cleanly.
if ! parse_flags "$@"; then
  ec=$?
  if [[ "$ec" -eq 2 ]]; then exit 0; fi
  exit "$ec"
fi

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

# Pre-flight ownership repair for Homebrew-touched paths that commonly cause
# `compinit` prompts and `brew install` failures (rb_sysopen permission denied)
# after ad-hoc setup. Runs read-only probes first; if any path is broken,
# requests sudo once up front, then repairs only the broken paths.
preflight_brew_paths() {
  local paths=(
    /usr/local/share/zsh
    /usr/local/share/zsh/site-functions
    /usr/local/var/homebrew
    /usr/local/Cellar
    /opt/homebrew/share/zsh
    /opt/homebrew/share/zsh/site-functions
    /opt/homebrew/var/homebrew
    /opt/homebrew/Cellar
  )
  local broken=()
  for p in "${paths[@]}"; do
    [[ -e "$p" ]] || continue
    [[ -w "$p" ]] || broken+=("$p")
  done
  if [[ ${#broken[@]} -eq 0 ]]; then
    return 0
  fi
  echo "Found ${#broken[@]} Homebrew path(s) the current user can't write to:" >&2
  printf '  %s\n' "${broken[@]}" >&2
  echo "Requesting sudo once to chown them to $USER:staff..." >&2
  sudo -v
  local failed=()
  for p in "${broken[@]}"; do
    if ! sudo chown -R "$USER:staff" "$p"; then
      failed+=("$p")
    fi
  done
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "chown failed for:" >&2
    printf '  %s\n' "${failed[@]}" >&2
    return 1
  fi
}

# Detect a pre-existing `brew install node` (Current-line node formula). If
# present and non-matching the pin, either prompt to unlink (interactive) or
# unlink unconditionally (--force-relink) so it doesn't shadow fnm/node@22.
remediate_existing_brew_node() {
  if ! command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if ! brew list --formula 2>/dev/null | grep -qx 'node'; then
    return 0
  fi
  local installed
  installed="$(brew list --versions node 2>/dev/null | awk '{print $2}')"
  if [[ -z "$installed" ]]; then
    return 0
  fi
  local major="${installed%%.*}"
  if [[ "$major" == "$PINNED_NODE_LTS_MAJOR" ]]; then
    return 0
  fi
  echo "Detected pre-existing brew Node v$installed (pin is v$PINNED_NODE_LTS_MAJOR)." >&2
  _unlink_brew_node() {
    if ! brew unlink node >/dev/null; then
      echo "  brew unlink node failed. Resolve manually (brew lock contention? partial install?) and re-run." >&2
      exit 1
    fi
  }
  if [[ "${FORCE_RELINK:-0}" == "1" ]]; then
    echo "  --force-relink set: running brew unlink node..." >&2
    _unlink_brew_node
    return 0
  fi
  echo "  This will shadow $( [[ "${BREW_ONLY:-0}" == "1" ]] && echo "node@${PINNED_NODE_LTS_MAJOR}" || echo "fnm-managed Node" )." >&2
  printf "  Run 'brew unlink node' now? [y/N, 60s timeout] " >&2
  local ans=""
  if ! read -r -t 60 ans; then
    echo >&2
    echo "  Prompt timed out. Re-run with --force-relink or unlink manually." >&2
    exit 1
  fi
  case "$ans" in
    y|Y|yes)
      _unlink_brew_node
      ;;
    *)
      echo "Aborting. Re-run with --force-relink or unlink manually." >&2
      exit 1
      ;;
  esac
}

# Apply a globals-restore list once Node is on PATH. Failures are reported but
# do not abort the bootstrap; each failing install's stderr is preserved so the
# user can diagnose registry / proxy / permission issues from the summary.
restore_npm_globals() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local installed=() skipped=() failed=()
  local failure_log
  failure_log="$(mktemp -t globals-restore.XXXXXX.log)"
  local pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
      skipped+=("$pkg")
      continue
    fi
    if npm install -g "${pkg}@latest" >/dev/null 2>>"$failure_log"; then
      installed+=("$pkg")
    else
      failed+=("$pkg")
      printf -- '--- %s failed ---\n' "$pkg" >> "$failure_log"
    fi
  done < <(parse_globals_file "$file")
  echo
  echo "Globals restore summary:"
  echo "  installed: ${#installed[@]} (${installed[*]:-none})"
  echo "  skipped:   ${#skipped[@]} (${skipped[*]:-none})"
  echo "  failed:    ${#failed[@]} (${failed[*]:-none})"
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo
    echo "  Failure details ($failure_log):"
    sed 's/^/    /' "$failure_log" >&2
  else
    rm -f "$failure_log"
  fi
}

log "Preflight: Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools not found. Triggering install..."
  xcode-select --install || true
  echo "Waiting for Command Line Tools installation to complete..."
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
fi

log "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  ensure_line_in_file_once "$HOME/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  ensure_line_in_file_once "$HOME/.zprofile" 'eval "$(/usr/local/bin/brew shellenv)"'
  eval "$(/usr/local/bin/brew shellenv)"
else
  require_cmd brew
fi

log "Pre-flight Homebrew path ownership"
preflight_brew_paths

log "Pre-existing brew Node remediation"
remediate_existing_brew_node

log "Base tools (git, curl)"
brew list git >/dev/null 2>&1 || brew install git
brew list curl >/dev/null 2>&1 || brew install curl

log "Terminal UX (lazygit, yazi)"
brew list lazygit >/dev/null 2>&1 || brew install lazygit
brew list yazi >/dev/null 2>&1 || brew install yazi

if [[ "${BREW_ONLY:-0}" == "1" ]]; then
  log "Node via brew node@${PINNED_NODE_LTS_MAJOR} (Plan B, --brew-only)"
  brew list "node@${PINNED_NODE_LTS_MAJOR}" >/dev/null 2>&1 || brew install "node@${PINNED_NODE_LTS_MAJOR}"
  # Only re-link when something other than the pinned keg owns the current node binary,
  # so reruns produce zero state mutations once the link is correct.
  active_node="$(readlink "$(brew --prefix)/bin/node" 2>/dev/null || true)"
  if [[ "$active_node" != *"node@${PINNED_NODE_LTS_MAJOR}/"* ]]; then
    brew link --force --overwrite "node@${PINNED_NODE_LTS_MAJOR}"
  fi
  SNIPPET="$REPO_ROOT/macos/zshrc.snippet.sh"
  ensure_snippet_in_zshrc_once "$SNIPPET"
  require_cmd node
  require_cmd npm
  node -v
  npm -v
else
  log "Node via fnm"
  brew list fnm >/dev/null 2>&1 || brew install fnm

  SNIPPET="$REPO_ROOT/macos/zshrc.snippet.sh"
  require_cmd fnm
  ensure_snippet_in_zshrc_once "$SNIPPET"

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
fi

log "Python via uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
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
  curl -fsSL https://claude.ai/install.sh | bash
fi
if command -v claude >/dev/null 2>&1; then
  claude --version || true
else
  echo "Claude Code installed, but 'claude' is not on PATH yet. Open a new terminal and try: claude --version" >&2
fi

log "Codex CLI"
npm list -g --depth=0 @openai/codex >/dev/null 2>&1 || npm install -g @openai/codex
require_cmd codex
codex --version

if [[ -n "${RESTORE_GLOBALS_FILE:-}" ]]; then
  log "Restoring npm globals from $RESTORE_GLOBALS_FILE"
  restore_npm_globals "$RESTORE_GLOBALS_FILE"
fi

log "Finish"
echo "Open a NEW terminal so .zprofile/.zshrc changes load."
echo "Then run (interactive auth):"
echo " - claude"
echo " - codex"
