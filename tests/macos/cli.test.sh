# shellcheck shell=bash
# Tests for parse_flags in macos/lib/cli.sh

# shellcheck disable=SC1091
source "$REPO_ROOT/macos/lib/cli.sh"

_make_globals_tmp() {
  local tmp
  tmp="$(mktemp -t flags-globals.XXXXXX)"
  printf 'pnpm\n@openai/codex\n' > "$tmp"
  echo "$tmp"
}

test_parse_flags_defaults_when_no_args() {
  parse_flags
  assert_equals "0" "$BREW_ONLY"
  assert_equals "1" "$USE_FNM"
  assert_equals "0" "$FORCE_RELINK"
  assert_equals ""  "$RESTORE_GLOBALS_FILE"
}

test_parse_flags_brew_only_sets_mode() {
  parse_flags --brew-only
  assert_equals "1" "$BREW_ONLY"
  assert_equals "0" "$USE_FNM"
}

test_parse_flags_fnm_keeps_default_mode() {
  parse_flags --fnm
  assert_equals "0" "$BREW_ONLY"
  assert_equals "1" "$USE_FNM"
}

test_parse_flags_force_relink() {
  parse_flags --force-relink
  assert_equals "1" "$FORCE_RELINK"
  assert_equals "1" "$USE_FNM"
}

test_parse_flags_brew_only_and_fnm_are_mutex() {
  assert_failure parse_flags --brew-only --fnm
  assert_failure parse_flags --fnm --brew-only
}

test_parse_flags_restore_globals_captures_path() {
  local f
  f="$(_make_globals_tmp)"
  parse_flags --restore-globals "$f"
  assert_equals "$f" "$RESTORE_GLOBALS_FILE"
  rm -f "$f"
}

test_parse_flags_restore_globals_requires_arg() {
  assert_failure parse_flags --restore-globals
}

test_parse_flags_restore_globals_fails_for_missing_file() {
  assert_failure parse_flags --restore-globals "/nonexistent/$$-flags.txt"
}

test_parse_flags_restore_globals_rejects_directory_path() {
  # A directory passes `-e` but not `-f`; the parser must reject it.
  assert_failure parse_flags --restore-globals "/tmp"
}

test_parse_flags_combo_brew_only_and_force_relink() {
  parse_flags --brew-only --force-relink
  assert_equals "1" "$BREW_ONLY"
  assert_equals "0" "$USE_FNM"
  assert_equals "1" "$FORCE_RELINK"
}

test_parse_flags_rejects_unknown_flag() {
  assert_failure parse_flags --no-such-flag
}
