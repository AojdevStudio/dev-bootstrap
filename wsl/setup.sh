#!/usr/bin/env bash
set -euo pipefail

echo "== WSL side setup =="

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y git curl ca-certificates
fi

# Claude Code install for Linux (per official docs):
# https://code.claude.com/docs/en/setup
curl -fsSL https://claude.ai/install.sh | bash

if ! grep -q "dev-bootstrap" ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<'EOF'
# ---- dev-bootstrap (WSL) ----
export PATH="$HOME/.local/bin:$PATH"
# -----------------------------
EOF
fi

echo "WSL setup complete."
