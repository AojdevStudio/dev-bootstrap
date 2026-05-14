# Minimal PATH + fnm activation for dev-bootstrap (macOS)

# Ensure common installer bins are on PATH
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# fnm (Node manager)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

# Non-LTS Node drift warning. Catches both odd-major Current releases
# (v23/v25/v27/v29) and even-but-Current drift (v26) that bit mbp13 and the
# primary dev Mac on 2026-05-13. The logic is inlined (not sourced from
# macos/lib/node-utils.sh::is_non_lts_node_version) to avoid an extra file
# read in every interactive shell startup — but the two MUST stay in sync.
# If you change one, change the other. Override the pin by exporting
# DEV_BOOTSTRAP_PINNED_NODE_MAJOR before this snippet runs (default 22).
if command -v node >/dev/null 2>&1; then
  __dev_bootstrap_node_v="$(node -v 2>/dev/null || true)"
  __dev_bootstrap_pin="${DEV_BOOTSTRAP_PINNED_NODE_MAJOR:-22}"
  __dev_bootstrap_major="${__dev_bootstrap_node_v#v}"
  __dev_bootstrap_major="${__dev_bootstrap_major%%.*}"
  if [[ "$__dev_bootstrap_major" =~ ^[0-9]+$ ]] && (( __dev_bootstrap_major != __dev_bootstrap_pin )); then
    printf '\033[33mdev-bootstrap: node is %s but pin is v%s (non-LTS drift)\033[0m\n' \
      "$__dev_bootstrap_node_v" "$__dev_bootstrap_pin" >&2
    printf '  recover: brew unlink node && brew link --force --overwrite node@%s\n' \
      "$__dev_bootstrap_pin" >&2
    printf '  or:      fnm install --lts && fnm default lts-latest\n' >&2
  fi
  unset __dev_bootstrap_node_v __dev_bootstrap_pin __dev_bootstrap_major
fi
