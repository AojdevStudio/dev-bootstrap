# shellcheck shell=bash
# Pure helpers used by macos/bootstrap.sh and macos/zshrc.snippet.sh.
# No side effects; safe to source from interactive shells.

PINNED_NODE_LTS_MAJOR="${PINNED_NODE_LTS_MAJOR:-22}"

is_non_lts_node_version() {
  # Returns 0 when the given Node version's major does not match the pinned
  # LTS major. Returns 1 otherwise, including for malformed or empty input.
  # Accepts "vX.Y.Z" or "X.Y.Z". Optional second arg overrides the pinned
  # major (defaults to $PINNED_NODE_LTS_MAJOR, default 22).
  local raw="${1:-}"
  raw="${raw#v}"
  local major="${raw%%.*}"
  local pin="${2:-$PINNED_NODE_LTS_MAJOR}"
  [[ "$major" =~ ^[0-9]+$ ]] || return 1
  [[ "$pin"   =~ ^[0-9]+$ ]] || return 1
  (( major != pin ))
}

parse_globals_file() {
  # Reads a globals-list file (one npm package name per line) and emits each
  # name on stdout, skipping blank lines and stripping `#` comments (both
  # whole-line comments and trailing comments). Returns 1 if the file is
  # missing or no path was given.
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
