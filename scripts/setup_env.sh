#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CREDENTIALS_JSON=${CLICKHOUSE_CREDENTIALS_JSON:-/Users/dataders/Developer/dotfiles_env/.clickhouse/credentials.json}
SQL_CREDENTIALS_JSON=${CLICKHOUSE_SQL_CREDENTIALS_JSON:-/Users/dataders/Developer/dotfiles_env/credentials/fusion.env.json}
ENDPOINT_ID=${CLICKHOUSE_ENDPOINT_ID:-a2e6b5b7-f27b-4950-bba5-e1fc0ec7ed0f}
CLOUD_API_BASE=${CLICKHOUSE_CLOUD_API_BASE:-https://api.clickhouse.cloud/v1}
LICENSE_ENV=${SHADOWTRAFFIC_LICENSE_ENV:-/Users/dataders/Developer/dotfiles_env/shadowtraffic/license.env}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

quote_env() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

api_get() {
  local path=$1
  curl -fsS -u "$API_KEY:$API_SECRET" "$CLOUD_API_BASE/$path"
}

require_command curl
require_command jq

[ -f "$CREDENTIALS_JSON" ] || die "missing ClickHouse credentials: $CREDENTIALS_JSON"

API_KEY=$(jq -er '.api_key' "$CREDENTIALS_JSON")
API_SECRET=$(jq -er '.api_secret' "$CREDENTIALS_JSON")
SERVICE_ID=$(
  jq -er --arg endpoint_id "$ENDPOINT_ID" '
    .service_query_keys
    | to_entries[]
    | select(.value.endpoint_id == $endpoint_id)
    | .key
  ' "$CREDENTIALS_JSON"
)
SERVICE_QUERY_KEY_ID=$(jq -er --arg service_id "$SERVICE_ID" '.service_query_keys[$service_id].key_id' "$CREDENTIALS_JSON")
SERVICE_QUERY_KEY_SECRET=$(jq -er --arg service_id "$SERVICE_ID" '.service_query_keys[$service_id].key_secret' "$CREDENTIALS_JSON")

ORG_ID=$(api_get organizations | jq -er '.result[0].id')
SERVICE_JSON=$(api_get "organizations/$ORG_ID/services/$SERVICE_ID")
HOST=$(printf '%s' "$SERVICE_JSON" | jq -er '.result.endpoints[] | select(.protocol == "https") | .host')
PORT=$(printf '%s' "$SERVICE_JSON" | jq -er '.result.endpoints[] | select(.protocol == "https") | .port')

if [ -f "$SQL_CREDENTIALS_JSON" ]; then
  KEY_ID=$(jq -er '.clickhouseUser' "$SQL_CREDENTIALS_JSON")
  KEY_SECRET=$(jq -er '.clickhousePassword' "$SQL_CREDENTIALS_JSON")
  SQL_HOST=$(jq -er '.clickhouseHost // empty' "$SQL_CREDENTIALS_JSON" || true)
  SQL_PORT=$(jq -er '.clickhousePort // empty' "$SQL_CREDENTIALS_JSON" || true)
  [ -z "$SQL_HOST" ] || HOST=$SQL_HOST
  [ -z "$SQL_PORT" ] || PORT=$SQL_PORT
else
  KEY_ID=$SERVICE_QUERY_KEY_ID
  KEY_SECRET=$SERVICE_QUERY_KEY_SECRET
fi

tmp_env="$ROOT/.env.tmp"
umask 077
{
  printf 'CLICKHOUSE_CREDENTIALS_JSON=%s\n' "$(quote_env "$CREDENTIALS_JSON")"
  printf 'CLICKHOUSE_SQL_CREDENTIALS_JSON=%s\n' "$(quote_env "$SQL_CREDENTIALS_JSON")"
  printf 'CLICKHOUSE_ENDPOINT_ID=%s\n' "$(quote_env "$ENDPOINT_ID")"
  printf 'CLICKHOUSE_SERVICE_ID=%s\n' "$(quote_env "$SERVICE_ID")"
  printf 'CLICKHOUSE_HOST=%s\n' "$(quote_env "$HOST")"
  printf 'CLICKHOUSE_PORT=%s\n' "$(quote_env "$PORT")"
  printf 'CLICKHOUSE_API_KEY=%s\n' "$(quote_env "$API_KEY")"
  printf 'CLICKHOUSE_API_SECRET=%s\n' "$(quote_env "$API_SECRET")"
  printf 'CLICKHOUSE_KEY_ID=%s\n' "$(quote_env "$KEY_ID")"
  printf 'CLICKHOUSE_KEY_SECRET=%s\n' "$(quote_env "$KEY_SECRET")"
  printf 'CLICKHOUSE_SERVICE_QUERY_KEY_ID=%s\n' "$(quote_env "$SERVICE_QUERY_KEY_ID")"
  printf 'CLICKHOUSE_SERVICE_QUERY_KEY_SECRET=%s\n' "$(quote_env "$SERVICE_QUERY_KEY_SECRET")"
  printf 'SHADOWTRAFFIC_LICENSE_ENV=%s\n' "$(quote_env "$LICENSE_ENV")"
} > "$tmp_env"
mv "$tmp_env" "$ROOT/.env"

printf 'wrote %s\n' "$ROOT/.env"
printf 'clickhouse service: %s\n' "$SERVICE_ID"
printf 'clickhouse host: %s:%s\n' "$HOST" "$PORT"
