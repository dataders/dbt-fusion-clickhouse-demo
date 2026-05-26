# Plan: dbt Fusion ClickHouse Cloud Demo Project

## Context

Build a self-contained demo project at `/Users/dataders/Developer/dbt-fusion-clickhouse-demo/` that demonstrates dbt Fusion in the VS Code extension against ClickHouse Cloud. The theme is a fake prediction market where people bet on silly data-industry outcomes. ShadowTraffic streams ~10 bets/sec into a ClickHouse Cloud source table.

Reference implementation for local Docker setup: `~/Developer/dotfiles/shadowtraffic-clickhouse/`

---

## Definition of Done

1. **Start/stop workflow** — `scripts/start.sh` creates the table and begins ingestion; `scripts/stop.sh` stops ingestion and drops the table. Demo-safe: always starts clean.
2. **dbt project** — builds correctly with `+materialized: view`, `+materialized: table`, and `+materialized: materialized_view` (one edit in `dbt_project.yml` switches modes)
3. **Talk track** with a written script covering: project overview, querying source data live in ClickHouse Cloud, `dbt run` as views, `dbt run` as tables, table lineage, syntax squiggles, and querying CTEs — all using dbt Fusion in VS Code
4. **Extra credit** — ~~project connected to dbt platform~~ (dbt platform doesn't support ClickHouse yet — skipped)

---

## Architecture

```
scripts/start.sh
  └─ CREATE TABLE clickstream.bets
  └─ docker run shadowtraffic ──10 bets/s──► clickstream.bets (ClickHouse Cloud)

dbt Fusion (VS Code / debug binary)
  └─ seeds/markets.csv
  └─ stg_bets → int_bet_markets → fct_market_odds

scripts/stop.sh
  └─ docker stop shadowtraffic
  └─ DROP TABLE clickstream.bets
```

---

## Data Model

### Source table: `clickstream.bets`
Created by `scripts/start.sh`, dropped by `scripts/stop.sh`.

```sql
bet_id         UUID
user_id        UUID
placed_at      DateTime64(3, 'UTC')
placed_date    Date  MATERIALIZED toDate(placed_at)
market_id      LowCardinality(String)
side           LowCardinality(String)   -- 'yes' | 'no'
amount         Decimal(12, 2)
implied_prob   Float32
channel        LowCardinality(String)   -- 'web' | 'mobile' | 'api'
region         LowCardinality(String)   -- 'na' | 'emea' | 'apac'
ingest_time    DateTime64(3, 'UTC')     DEFAULT now64(3)
```

### Seed: `seeds/markets.csv`
10 market IDs are **fixed** in ShadowTraffic config. Questions/categories can be updated in the seed at any time without touching the streaming config.

```
market_id,question,category,close_date,initial_yes_prob
mk-databricks-ipo,Will Databricks IPO in 2026?,Corporate,2026-12-31,0.72
mk-agents-de,Will AI agents replace half of data engineers by 2027?,AI/ML,2027-12-31,0.31
mk-dbt-10m,Will dbt exceed 10M downloads in 2026?,Open Source,2026-12-31,0.61
mk-spark-decline,Will Spark usage decline 20% by 2028?,Technology,2028-12-31,0.44
mk-llm-sql,Will LLMs replace SQL as the primary analytics language by 2030?,AI/ML,2030-12-31,0.28
mk-openai-dw,Will OpenAI launch their own data warehouse product?,AI/ML,2027-06-30,0.41
mk-pope-clickhouse,Will the Pope say that ClickHouse is better than Spark for streaming?,Meme,2026-12-31,0.04
mk-ryan-openhouse,Will Ryan Waters announce at Open House that the dbt Fusion ClickHouse adapter is now in public alpha?,dbt Labs,2026-12-31,0.67
mk-dbt-acq,Will dbt Labs be acquired before end of 2027?,Corporate,2027-12-31,0.35
mk-parquet-rip,Will Parquet be replaced as the de facto analytics file format by 2030?,Technology,2030-12-31,0.22
```

### ShadowTraffic generator (`shadowtraffic/config.json`)
- URL: `https://${CLICKHOUSE_HOST}:8443/`
- Auth: `user=${CLICKHOUSE_KEY_ID}&password=${CLICKHOUSE_KEY_SECRET}`
- `market_id`: oneOf the 10 fixed IDs above
- `side`: weightedOneOf `yes` (45%), `no` (55%)
- `amount`: uniformDistribution [10, 1000] decimals 2
- `implied_prob`: uniformDistribution [0.05, 0.95] decimals 2
- `channel`: weightedOneOf `web` (55%), `mobile` (30%), `api` (15%)
- `region`: oneOf `na`, `emea`, `apac`
- `throttleMs: 100` → ~10 rows/sec

---

## Files to Create

### Project root
- `dbt_project.yml` — project `clickstream_demo`, profile `clickstream_demo`
- `profiles.yml` — ClickHouse Cloud, reads env vars, `secure: true`, port `8443`
- `packages.yml` — `dbt-clickhouse` adapter

### Seeds
- `seeds/markets.csv`

### Models
- `models/sources.yml` — source `clickstream.bets`
- `models/staging/stg_bets.sql`
- `models/intermediate/int_bet_markets.sql` — LEFT JOIN stg_bets + markets seed
- `models/marts/fct_market_odds.sql` — GROUP BY market/side: sum(amount), count(bets), avg(implied_prob), max(placed_at)

### ShadowTraffic
- `shadowtraffic/config.json`

### Scripts
- `scripts/setup_env.sh` — calls ClickHouse Cloud REST API to discover hostname from `endpoint_id`, writes `.env`
- `scripts/start.sh` — runs `CREATE DATABASE / CREATE TABLE` via curl, then starts ShadowTraffic Docker container; idempotent (`IF NOT EXISTS`)
- `scripts/stop.sh` — stops ShadowTraffic container, then `DROP TABLE clickstream.bets`
- `scripts/count_bets.sh` — `SELECT count(), max(placed_at) FROM clickstream.bets` — run live during demo
- `scripts/dbt` — exec wrapper: `exec ~/Developer/fs.clickhouse-clean-materialized-views/target/debug/dbt "$@"`

### Environment
- `.env.example`
- `.env` — gitignored
- `.envrc` — `dotenv .env && export PATH="$PWD/scripts:$PATH"`

---

## Credential Mapping

From `/Users/dataders/Developer/dotfiles_env/.clickhouse/credentials.json`:

| Env var | Source |
|---|---|
| `CLICKHOUSE_API_KEY` | `api_key` |
| `CLICKHOUSE_API_SECRET` | `api_secret` |
| `CLICKHOUSE_KEY_ID` | `service_query_keys[*].key_id` |
| `CLICKHOUSE_KEY_SECRET` | `service_query_keys[*].key_secret` |
| `CLICKHOUSE_HOST` | discovered via Cloud API from `endpoint_id: a2e6b5b7-f27b-4950-bba5-e1fc0ec7ed0f` |

---

## Materialization switching

One edit in `dbt_project.yml` switches modes:

```yaml
models:
  clickstream_demo:
    +materialized: view      # phase 1
    # +materialized: table   # phase 2
    # +materialized: materialized_view  # phase 3
```

---

## Talk Track (written script)

### 1. Setup / project overview
> "This is a fake prediction market — people are betting on data-industry outcomes. Will Databricks IPO? Will agents replace data engineers? The bets are streaming into ClickHouse Cloud right now at about 10 per second."

- Show `seeds/markets.csv` — the 10 market questions
- Show `models/` folder structure in VS Code file tree
- Run `scripts/count_bets.sh` twice, 5 seconds apart — "see it growing"

### 2. Query source data in ClickHouse Cloud
- Open `models/sources.yml` in VS Code
- Run `SELECT * FROM clickstream.bets LIMIT 10` via dbt Fusion's inline query runner
- Point out `market_id`, `side`, `amount`, `implied_prob`

### 3. dbt run — views
> "Let's build the project. Everything is a view right now — every query goes back to the raw source."

- `dbt seed && dbt run`
- Query `fct_market_odds` — explain it's scanning source live
- Run `scripts/count_bets.sh` — show source still growing, view reflects it

### 4. Lineage
- Open dbt Fusion lineage panel in VS Code
- Walk `bets → stg_bets → int_bet_markets → fct_market_odds`
- Mention the seed join at `int_bet_markets`

### 5. Syntax squiggles
- Introduce a typo in a model (e.g., reference a nonexistent column)
- Show red squiggle appear without running anything
- Fix it

### 6. Querying CTEs
- Open `int_bet_markets.sql`
- Highlight a CTE and run it inline with dbt Fusion
- Show the result preview without building the whole model

### 7. dbt run — tables
> "Now let's materialize as tables — a snapshot in time."

- Edit `dbt_project.yml`: `+materialized: table`
- `dbt run`
- Query `fct_market_odds` — run `count_bets.sh` to show source growing, but mart result is frozen
- > "That's the difference — tables are a point-in-time copy."

### 8. (Bonus) Materialized views
> "Now for the real ClickHouse magic."

- Edit `dbt_project.yml`: `+materialized: materialized_view`
- `dbt run`
- Query `fct_market_odds` twice, ~10 seconds apart — odds are shifting without re-running dbt
- > "ClickHouse materialized views update automatically as bets come in."

---

## Setup order (first run)

1. `scripts/setup_env.sh` → populates `.env`
2. `direnv allow` (or `source .env && export PATH="$PWD/scripts:$PATH"`)
3. `scripts/start.sh` — creates table + starts streaming
4. `scripts/count_bets.sh` — confirm rows arriving
5. `dbt seed && dbt run`

---

## Notes

- `stop.sh` drops the table — each demo starts from zero, no stale data
- `profiles.yml` uses `{{ env_var(...) }}` — no credentials in git
- ShadowTraffic image: `shadowtraffic/shadowtraffic:latest`
- License: `~/Developer/dotfiles_env/shadowtraffic/license.env`
- fs debug binary: `~/Developer/fs.clickhouse-clean-materialized-views/target/debug/dbt` (305.5MB, already built)
