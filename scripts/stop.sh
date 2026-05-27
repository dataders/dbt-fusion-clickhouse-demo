#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONTAINER_NAME=${SHADOWTRAFFIC_CONTAINER_NAME:-dbt-fusion-clickhouse-demo-shadowtraffic}

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

clickhouse_query() {
  local sql=$1
  curl -fsS -u "$CLICKHOUSE_KEY_ID:$CLICKHOUSE_KEY_SECRET" \
    "https://$CLICKHOUSE_HOST:${CLICKHOUSE_PORT:-8443}/" \
    --data-binary "$sql"
}

drop_demo_relations() {
  clickhouse_query "DROP TABLE IF EXISTS clickstream.fct_market_odds_mv" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.fct_market_odds" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.int_bet_markets_mv" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.int_bet_markets" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.stg_bets_mv" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.stg_bets" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.markets" >/dev/null
  clickhouse_query "DROP TABLE IF EXISTS clickstream.bets" >/dev/null
  clickhouse_query 'DROP TABLE IF EXISTS clickstream."bets"' >/dev/null
  clickhouse_query 'DROP TABLE IF EXISTS clickstream."int_bet_markets2"' >/dev/null
  clickhouse_query 'DROP TABLE IF EXISTS clickstream."markets"' >/dev/null
  clickhouse_query 'DROP TABLE IF EXISTS clickstream."total_bets"' >/dev/null
  clickhouse_query 'DROP VIEW IF EXISTS clickstream."fct_market_odds"' >/dev/null
  clickhouse_query 'DROP VIEW IF EXISTS clickstream."int_bet_markets"' >/dev/null
  clickhouse_query 'DROP VIEW IF EXISTS clickstream."stg_bets"' >/dev/null
  clickhouse_query 'DROP VIEW IF EXISTS clickstream."stg_markets"' >/dev/null
  clickhouse_query 'DROP VIEW IF EXISTS clickstream."int_bet_markets2_mv"' >/dev/null
}

require_command curl
require_command docker
load_env

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
drop_demo_relations

printf 'stopped: %s\n' "$CONTAINER_NAME"
printf 'dropped: clickstream.bets and demo dbt relations\n'
