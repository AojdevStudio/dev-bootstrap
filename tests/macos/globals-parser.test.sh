# shellcheck shell=bash
# Tests for parse_globals_file in macos/lib/node-utils.sh

# shellcheck disable=SC1091
source "$REPO_ROOT/macos/lib/node-utils.sh"

_make_globals_fixture() {
  local content="$1"
  local tmp
  tmp="$(mktemp -t globals.XXXXXX)"
  printf '%s' "$content" > "$tmp"
  echo "$tmp"
}

test_parse_globals_file_emits_each_package() {
  local f
  f="$(_make_globals_fixture $'@anthropic-ai/claude-code\n@openai/codex\npnpm\n')"
  local got
  got="$(parse_globals_file "$f")"
  rm -f "$f"
  assert_equals "$'@anthropic-ai/claude-code\n@openai/codex\npnpm'" "$got"
}

test_parse_globals_file_skips_blank_lines() {
  local f
  f="$(_make_globals_fixture $'pnpm\n\n@openai/codex\n\n\n')"
  local got
  got="$(parse_globals_file "$f")"
  rm -f "$f"
  assert_equals "$'pnpm\n@openai/codex'" "$got"
}

test_parse_globals_file_skips_hash_comment_lines() {
  local f
  f="$(_make_globals_fixture $'# saved on 2026-05-13\npnpm\n# legacy:\n# typescript@4\n')"
  local got
  got="$(parse_globals_file "$f")"
  rm -f "$f"
  assert_equals 'pnpm' "$got"
}

test_parse_globals_file_strips_trailing_hash_comment() {
  local f
  f="$(_make_globals_fixture $'pnpm   # corepack-bypass\n@openai/codex\n')"
  local got
  got="$(parse_globals_file "$f")"
  rm -f "$f"
  assert_equals "$'pnpm\n@openai/codex'" "$got"
}

test_parse_globals_file_handles_scoped_packages_with_comments() {
  # Scoped names (@org/pkg) must survive whole-line and trailing # comments.
  local f
  f="$(_make_globals_fixture $'# saved 2026-05-13\n@anthropic-ai/claude-code   # native installer covers this, skip\n@openai/codex@latest\n@scope/with-version@1.2.3 # pinned\n')"
  local got
  got="$(parse_globals_file "$f")"
  rm -f "$f"
  assert_equals "$'@anthropic-ai/claude-code\n@openai/codex@latest\n@scope/with-version@1.2.3'" "$got"
}

test_parse_globals_file_returns_nonzero_when_missing() {
  assert_failure parse_globals_file "/nonexistent/path-$$-globals.txt"
}

test_parse_globals_file_returns_nonzero_when_no_arg() {
  assert_failure parse_globals_file
}
