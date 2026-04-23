#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
FETCH_SCRIPT="$ROOT_DIR/scripts/fetch_hagezi_rpz.sh"
VALIDATE_SCRIPT="$ROOT_DIR/scripts/validate_rpz.sh"
UPDATE_SCRIPT="$ROOT_DIR/scripts/update_blocklist.sh"
FIXTURES_DIR="$ROOT_DIR/tests/fixtures"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  file_path=$1
  expected=$2

  if ! grep -Fq "$expected" "$file_path"; then
    fail "Expected '$expected' in $file_path"
  fi
}

assert_not_exists() {
  path=$1

  if [ -e "$path" ]; then
    fail "Did not expect $path to exist"
  fi
}

assert_exists() {
  path=$1

  if [ ! -e "$path" ]; then
    fail "Expected $path to exist"
  fi
}

test_validate_accepts_rpz() {
  "$VALIDATE_SCRIPT" "$FIXTURES_DIR/sample-rpz.txt"
}

test_validate_rejects_non_rpz() {
  if "$VALIDATE_SCRIPT" "$FIXTURES_DIR/sample-rpz-invalid.txt" >/dev/null 2>&1; then
    fail "validate_rpz.sh accepted invalid input"
  fi
}

test_fetch_copies_source_file() {
  output_file="$TMP_DIR/downloaded-rpz.txt"

  "$FETCH_SCRIPT" --source-file "$FIXTURES_DIR/sample-rpz.txt" --output "$output_file"

  assert_exists "$output_file"
  assert_file_contains "$output_file" "example.com CNAME ."
}

test_update_installs_zone_and_metadata() {
  output_dir="$TMP_DIR/output"
  state_dir="$TMP_DIR/state"

  "$UPDATE_SCRIPT" \
    --source-file "$FIXTURES_DIR/sample-rpz.txt" \
    --output-dir "$output_dir" \
    --state-dir "$state_dir" \
    --zone-name "hagezi-test.local" \
    --list-profile "light"

  assert_exists "$output_dir/hagezi-rpz.zone"
  assert_exists "$output_dir/hagezi-rpz.conf"
  assert_exists "$state_dir/last-update.env"
  assert_file_contains "$output_dir/hagezi-rpz.conf" "module-config: \"respip validator iterator\""
  assert_file_contains "$output_dir/hagezi-rpz.conf" "url: \"https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/light.txt\""
  assert_file_contains "$output_dir/hagezi-rpz.zone" "example.com CNAME ."
  assert_file_contains "$state_dir/last-update.env" "LIST_PROFILE=light"
}

test_update_rejects_invalid_zone() {
  output_dir="$TMP_DIR/invalid-output"
  state_dir="$TMP_DIR/invalid-state"

  if "$UPDATE_SCRIPT" \
    --source-file "$FIXTURES_DIR/sample-rpz-invalid.txt" \
    --output-dir "$output_dir" \
    --state-dir "$state_dir" \
    --zone-name "hagezi-test.local" \
    --list-profile "light" >/dev/null 2>&1; then
    fail "update_blocklist.sh accepted invalid zone data"
  fi

  assert_not_exists "$output_dir/hagezi-rpz.zone"
}

test_validate_accepts_rpz
test_validate_rejects_non_rpz
test_fetch_copies_source_file
test_update_installs_zone_and_metadata
test_update_rejects_invalid_zone

printf 'All tests passed.\n'
