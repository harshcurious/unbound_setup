#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage: validate_rpz.sh PATH
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

[ "$#" -eq 1 ] || {
  usage >&2
  exit 1
}

ZONE_FILE=$1
[ -f "$ZONE_FILE" ] || die "Zone file not found: $ZONE_FILE"

awk '
  BEGIN {
    saw_soa = 0
    saw_ns = 0
    saw_action = 0
  }
  /^[[:space:]]*;/ || /^[[:space:]]*$/ {
    next
  }
  $0 ~ /^\$TTL([[:space:]]|$)/ {
    next
  }
  $0 ~ /[[:space:]]SOA[[:space:]]/ {
    saw_soa = 1
    next
  }
  $0 ~ /[[:space:]]NS[[:space:]]/ {
    saw_ns = 1
    next
  }
  $0 ~ /[[:space:]]CNAME[[:space:]]/ || $0 ~ /[[:space:]]A[[:space:]]/ || $0 ~ /[[:space:]]AAAA[[:space:]]/ || $0 ~ /[[:space:]]TXT[[:space:]]/ {
    saw_action = 1
    next
  }
  {
    invalid = 1
  }
  END {
    if (invalid || !saw_soa || !saw_ns || !saw_action) {
      exit 1
    }
  }
' "$ZONE_FILE" || die "Invalid RPZ zone file: $ZONE_FILE"

printf 'Valid RPZ zone: %s\n' "$ZONE_FILE"
