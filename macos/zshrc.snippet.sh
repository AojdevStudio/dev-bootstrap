# Minimal PATH + fnm activation for dev-bootstrap (macOS)

# Ensure common installer bins are on PATH
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# fnm (Node manager)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi
