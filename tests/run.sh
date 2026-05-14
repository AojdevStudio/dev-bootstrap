#!/usr/bin/env bash
# Minimal bash test runner.
#
# Discovers every tests/**/*.test.sh, sources it, then invokes every function
# named test_*. A test passes when its function returns 0; any non-zero return
# (including the implicit return from `set -e` after a failed assertion) counts
# as failure. Output mirrors the contract of common runners: one line per test,
# tally at the end, exit code = number of failures.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { echo "tests/run.sh: cannot cd to $REPO_ROOT" >&2; exit 1; }

PASS=0
FAIL=0
FAILED=()

assert_equals() {
  # Usage: assert_equals <expected> <actual> [<message>]
  local expected="$1"
  local actual="$2"
  local message="${3:-values not equal}"
  if [[ "$expected" != "$actual" ]]; then
    printf '    %s\n      expected: %q\n      actual:   %q\n' "$message" "$expected" "$actual" >&2
    return 1
  fi
}

assert_success() {
  # Usage: assert_success <command...>
  if ! "$@" >/dev/null 2>&1; then
    printf '    expected success, got exit %d running: %s\n' "$?" "$*" >&2
    return 1
  fi
}

assert_failure() {
  # Usage: assert_failure <command...>
  if "$@" >/dev/null 2>&1; then
    printf '    expected non-zero exit, got success running: %s\n' "$*" >&2
    return 1
  fi
}

shopt -s nullglob globstar
TEST_FILES=( tests/**/*.test.sh )
shopt -u nullglob globstar

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "no tests found under tests/" >&2
  exit 1
fi

for f in "${TEST_FILES[@]}"; do
  echo "── $f"
  # shellcheck disable=SC1090
  source "$f"
done

mapfile -t TESTS < <(declare -F | awk '/^declare -f test_/{print $3}')

for t in "${TESTS[@]}"; do
  # set -e so any failed assert_* in the test body fails the subshell, even
  # when later commands in the same test happen to succeed.
  if ( set -e; "$t" ); then
    printf '  PASS  %s\n' "$t"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s\n' "$t"
    FAIL=$((FAIL + 1))
    FAILED+=("$t")
  fi
done

echo "────"
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -gt 0 ]]; then
  printf 'Failed:\n'
  for t in "${FAILED[@]}"; do printf '  - %s\n' "$t"; done
fi
exit "$FAIL"
