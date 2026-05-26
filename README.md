# dbt Fusion ClickHouse Demo

Self-contained dbt Fusion demo for a fake prediction market streaming into
ClickHouse Cloud with ShadowTraffic.

## Setup

```sh
scripts/setup_env.sh
direnv allow
scripts/start.sh
scripts/count_bets.sh
dbt seed && dbt run
```

`scripts/start.sh` always resets the demo source and dbt relations before it
starts the ShadowTraffic container. `scripts/stop.sh` stops ingestion and drops
the demo tables.

`scripts/dbt run` also clears the three demo model relations first. That keeps
switching between view, table, and materialized_view modes a one-edit workflow
with the current Fusion ClickHouse preview binary.

`scripts/setup_env.sh` uses the ClickHouse Cloud API credential file for service
discovery, then uses the direct SQL credentials from
`~/Developer/dotfiles_env/credentials/fusion.env.json` when that file exists.

## Materialization Modes

Change one line in `dbt_project.yml`:

```yaml
models:
  clickstream_demo:
    +materialized: view
    # +materialized: table
    # +materialized: materialized_view
```

For materialized views, `fct_market_odds` uses `SummingMergeTree()` and the
generated physical materialized view is named `fct_market_odds_mv`.

## Demo Script

Use `docs/talk_track.md` for the VS Code/dbt Fusion talk track.
