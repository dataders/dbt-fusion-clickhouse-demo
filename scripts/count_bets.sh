#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

load_env() {
  [ -f "$ROOT/.env" ] || die "missing .env; run scripts/setup_env.sh first"
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
}

require_command curl
load_env

curl -fsS -u "$CLICKHOUSE_KEY_ID:$CLICKHOUSE_KEY_SECRET" \
  "https://$CLICKHOUSE_HOST:${CLICKHOUSE_PORT:-8443}/" \
  --data-binary "SELECT count() AS bets, max(placed_at) AS latest_placed_at FROM clickstream.bets FORMAT PrettyCompact"
