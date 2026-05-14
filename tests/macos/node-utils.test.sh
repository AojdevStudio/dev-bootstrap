# shellcheck shell=bash
# Tests for macos/lib/node-utils.sh

# shellcheck disable=SC1091
source "$REPO_ROOT/macos/lib/node-utils.sh"

test_is_non_lts_node_version_detects_v25() {
  assert_success is_non_lts_node_version "v25.7.0"
}

test_is_non_lts_node_version_accepts_pinned_v22() {
  assert_failure is_non_lts_node_version "v22.11.0"
}

test_is_non_lts_node_version_detects_even_v26() {
  # 2026-05-13 incident: primary Mac was on v26.0.0 (even-major-but-Current).
  # Broader rule from the odd-only AC: anything that isn't the pinned LTS warns.
  assert_success is_non_lts_node_version "v26.0.0"
}

test_is_non_lts_node_version_detects_v23() {
  assert_success is_non_lts_node_version "v23.0.0"
}

test_is_non_lts_node_version_quiet_on_malformed_input() {
  assert_failure is_non_lts_node_version "garbage"
}

test_is_non_lts_node_version_quiet_on_empty_input() {
  assert_failure is_non_lts_node_version ""
}

test_is_non_lts_node_version_honours_pin_override() {
  # When the LTS pin moves (e.g. v24 becomes Active LTS), the second arg lets
  # callers express the new pin without editing the helper.
  assert_failure is_non_lts_node_version "v24.0.0" "24"
  assert_success is_non_lts_node_version "v22.11.0" "24"
}
