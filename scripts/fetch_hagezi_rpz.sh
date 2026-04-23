#!/bin/sh

set -eu

usage() {
  cat <<'EOF'
Usage:
  fetch_hagezi_rpz.sh [--profile PROFILE] [--output PATH]
  fetch_hagezi_rpz.sh --source-file PATH [--output PATH]

Profiles:
  light, normal, pro, pro.mini, pro.plus, pro.plus.mini,
  ultimate, ultimate.mini, tif, tif.medium, tif.mini,
  fake, popupads
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

profile_to_url() {
  case "$1" in
    light) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/light.txt' ;;
    normal) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/multi.txt' ;;
    pro) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/pro.txt' ;;
    pro.mini) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/pro.mini.txt' ;;
    pro.plus) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/pro.plus.txt' ;;
    pro.plus.mini) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/pro.plus.mini.txt' ;;
    ultimate) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/ultimate.txt' ;;
    ultimate.mini) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/ultimate.mini.txt' ;;
    tif) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/tif.txt' ;;
    tif.medium) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/tif.medium.txt' ;;
    tif.mini) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/tif.mini.txt' ;;
    fake) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/fake.txt' ;;
    popupads) printf '%s\n' 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/rpz/popupads.txt' ;;
    *) die "Unsupported profile: $1" ;;
  esac
}

write_to_output() {
  source_path=$1
  output_path=$2

  if [ "$output_path" = "-" ]; then
    cat "$source_path"
    return 0
  fi

  cat "$source_path" > "$output_path"
}

PROFILE='light'
OUTPUT='-'
SOURCE_FILE=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      [ "$#" -ge 2 ] || die 'Missing value for --profile'
      PROFILE=$2
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || die 'Missing value for --output'
      OUTPUT=$2
      shift 2
      ;;
    --source-file)
      [ "$#" -ge 2 ] || die 'Missing value for --source-file'
      SOURCE_FILE=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if [ -n "$SOURCE_FILE" ]; then
  [ -f "$SOURCE_FILE" ] || die "Source file not found: $SOURCE_FILE"
  write_to_output "$SOURCE_FILE" "$OUTPUT"
  exit 0
fi

URL=$(profile_to_url "$PROFILE")
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT INT TERM

if command -v curl >/dev/null 2>&1; then
  curl --fail --silent --show-error --location "$URL" --output "$TMP_FILE"
elif command -v wget >/dev/null 2>&1; then
  wget --quiet --output-document="$TMP_FILE" "$URL"
else
  die 'curl or wget is required to fetch a remote blocklist'
fi

write_to_output "$TMP_FILE" "$OUTPUT"
