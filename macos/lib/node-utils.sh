# shellcheck shell=bash
# Pure helpers for macos/bootstrap.sh.

# Canonical pin for the LTS Node major. If you bump this, also update:
#   - macos/zshrc.snippet.sh (DEV_BOOTSTRAP_PINNED_NODE_MAJOR default)
#   - README.md "Migrating a Mac that was already set up ad-hoc" recipe
#   - macos/bootstrap.sh log line referencing the pin
PINNED_NODE_LTS_MAJOR="${PINNED_NODE_LTS_MAJOR:-22}"

is_non_lts_node_version() {
  # Returns 0 when the input version's major != pin. Accepts "vX.Y.Z" or "X.Y.Z".
  # Returns 1 for the pinned major, empty input, or malformed input.
  # Optional second arg overrides the pin.
  local raw="${1:-}"
  raw="${raw#v}"
  local major="${raw%%.*}"
  local pin="${2:-$PINNED_NODE_LTS_MAJOR}"
  [[ "$major" =~ ^[0-9]+$ ]] || return 1
  [[ "$pin"   =~ ^[0-9]+$ ]] || return 1
  (( major != pin ))
}

parse_globals_file() {
  # Emits each npm package name on stdout, skipping blank lines and stripping
  # `#` comments (whole-line and trailing). Returns 1 if the file is missing.
  local file="${1:-}"
  [[ -n "$file" && -f "$file" ]] || return 1
  awk '
    {
      sub(/#.*$/, "")
      sub(/^[[:space:]]+/, "")
      sub(/[[:space:]]+$/, "")
      if (length($0) > 0) print
    }
  ' "$file"
}
