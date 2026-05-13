# shellcheck shell=bash
# CLI flag parsing for macos/bootstrap.sh.
# parse_flags sets the following globals (all initialized to defaults on every call):
#   BREW_ONLY            "0" / "1"   — install node@22 via brew, skip fnm path
#   USE_FNM              "0" / "1"   — install LTS via fnm (default mode)
#   FORCE_RELINK         "0" / "1"   — non-interactive remediation of pre-existing brew Node
#   RESTORE_GLOBALS_FILE path        — file of npm package names to reinstall (or empty)
# Returns 0 on success, 1 on usage error (unknown flag, missing arg, mutex violation,
# or --restore-globals pointing at a missing file).

parse_flags() {
  BREW_ONLY=0
  USE_FNM=1
  FORCE_RELINK=0
  RESTORE_GLOBALS_FILE=""

  local brew_only_explicit=0
  local fnm_explicit=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --brew-only)
        BREW_ONLY=1
        USE_FNM=0
        brew_only_explicit=1
        ;;
      --fnm)
        BREW_ONLY=0
        USE_FNM=1
        fnm_explicit=1
        ;;
      --force-relink)
        FORCE_RELINK=1
        ;;
      --restore-globals)
        shift
        if [[ $# -eq 0 ]]; then
          echo "--restore-globals requires a file path" >&2
          return 1
        fi
        if [[ ! -f "$1" ]]; then
          echo "--restore-globals: file not found: $1" >&2
          return 1
        fi
        RESTORE_GLOBALS_FILE="$1"
        ;;
      -h|--help)
        cat <<'USAGE'
Usage: macos/bootstrap.sh [options]

  --brew-only             Install node@22 via Homebrew; skip fnm.
                          Mutually exclusive with --fnm.
  --fnm                   Install LTS Node via fnm (default).
                          Mutually exclusive with --brew-only.
  --force-relink          Auto-resolve a pre-existing `brew install node`
                          by `brew unlink node` without prompting. Safe
                          for CI / non-interactive reruns.
  --restore-globals FILE  After Node is installed, reinstall each npm
                          package named in FILE (one per line, blank lines
                          and `# comments` ignored). Failures are reported
                          but do not abort the bootstrap.
  -h, --help              Show this help and exit.
USAGE
        return 2
        ;;
      *)
        echo "unknown argument: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  if [[ "$brew_only_explicit" == "1" && "$fnm_explicit" == "1" ]]; then
    echo "--brew-only and --fnm are mutually exclusive — pick one" >&2
    return 1
  fi

  return 0
}
