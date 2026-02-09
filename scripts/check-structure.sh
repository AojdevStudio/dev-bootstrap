#!/usr/bin/env bash
set -euo pipefail

required_paths=(
  "README.md"
  "LICENSE"
  "bootstrap.ps1"
  "wsl/setup.sh"
  "macos/bootstrap.sh"
  "macos/zshrc.snippet.sh"
  "scripts/check-structure.ps1"
  "scripts/check-structure.sh"
  ".github/workflows/repo-health.yml"
)

missing=()
for p in "${required_paths[@]}"; do
  if [[ ! -e "$p" ]]; then
    missing+=("$p")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing required paths:" >&2
  for m in "${missing[@]}"; do
    echo " - $m" >&2
  done
  exit 1
fi

echo "OK: repo structure looks correct."
