#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CONTAINER_NAME=${SHADOWTRAFFIC_CONTAINER_NAME:-dbt-fusion-clickhouse-demo-shadowtraffic}
LICENSE_ENV=${SHADOWTRAFFIC_LICENSE_ENV:-/Users/dataders/Developer/dotfiles_env/shadowtraffic/license.env}
RENDERED_CONFIG="$ROOT/.tmp/shadowtraffic-config.json"

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
}

create_source_table() {
  clickhouse_query "CREATE DATABASE IF NOT EXISTS clickstream" >/dev/null
  drop_demo_relations
  clickhouse_query "
CREATE TABLE clickstream.bets
(
    bet_id UInt64,
    user_id UInt32,
    placed_at DateTime64(3, 'UTC'),
    placed_date Date MATERIALIZED toDate(placed_at),
    market_id LowCardinality(String),
    side LowCardinality(String),
    amount Decimal(12, 2),
    implied_prob Float32,
    channel LowCardinality(String),
    region LowCardinality(String),
    ingest_time DateTime64(3, 'UTC') DEFAULT now64(3)
)
ENGINE = MergeTree
ORDER BY (placed_at, bet_id)
" >/dev/null
}

render_shadowtraffic_config() {
  mkdir -p "$(dirname "$RENDERED_CONFIG")"
  jq \
    --arg host "$CLICKHOUSE_HOST" \
    --arg key_id "$CLICKHOUSE_KEY_ID" \
    --arg key_secret "$CLICKHOUSE_KEY_SECRET" \
    '.generators[0].url = ("https://" + $host + ":8443/")
     | .generators[0].queryParams.user = $key_id
     | .generators[0].queryParams.password = $key_secret' \
    "$ROOT/shadowtraffic/config.json" > "$RENDERED_CONFIG"
  chmod 600 "$RENDERED_CONFIG"
}

require_command curl
require_command docker
require_command jq
load_env

[ -f "$LICENSE_ENV" ] || die "missing ShadowTraffic license env: $LICENSE_ENV"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
create_source_table
render_shadowtraffic_config

docker run -d \
  --name "$CONTAINER_NAME" \
  --env-file "$LICENSE_ENV" \
  -v "$RENDERED_CONFIG:/home/config.json:ro" \
  shadowtraffic/shadowtraffic:latest \
  --config /home/config.json >/dev/null

printf 'streaming: %s -> clickstream.bets\n' "$CONTAINER_NAME"
