# Minimal PATH + fnm activation for dev-bootstrap (Linux)
#
# Mirrors macos/zshrc.snippet.sh. linux/bootstrap.sh injects an equivalent
# block into ~/.bashrc and ~/.zshrc automatically; this file is kept for
# users who prefer to source it manually.

export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$HOME/.bun/bin:$PATH"

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi
