# Talk Track

## 1. Setup and project overview

"This is a fake prediction market. People are betting on data-industry outcomes:
Databricks IPO, agents replacing data engineers, dbt downloads, Spark decline,
and the ClickHouse adapter going public alpha. ShadowTraffic is streaming bets
into ClickHouse Cloud at about 10 per second."

Show `seeds/markets.csv`, then show the `models/` tree:
`stg_bets`, `int_bet_markets`, and `fct_market_odds`.

Run:

```sh
scripts/count_bets.sh
sleep 5
scripts/count_bets.sh
```

"The source table is live. The row count is moving while we work."

## 2. Query source data in ClickHouse Cloud

Open `models/sources.yml` in VS Code. Run this inline with dbt Fusion:

```sql
select *
from clickstream.bets
limit 10
```

Point at `market_id`, `side`, `amount`, and `implied_prob`.

## 3. dbt run as views

"Everything is a view right now. Every query goes back to the live raw source."

In `dbt_project.yml`, use:

```yaml
+materialized: view
```

Run:

```sh
dbt seed && dbt run
```

Query:

```sql
select *
from clickstream.fct_market_odds
order by total_amount desc
limit 10
```

Run `scripts/count_bets.sh` again and refresh the mart query. "The source keeps
growing, and the view reflects it."

## 4. Lineage

Open dbt Fusion lineage in VS Code. Walk:

```text
bets -> stg_bets -> int_bet_markets -> fct_market_odds
```

Call out the `markets` seed joining into `int_bet_markets`.

## 5. Syntax squiggles

Open `models/staging/stg_bets.sql`. Temporarily change `amount` to
`amount_bad`. Show the red squiggle without running dbt. Fix the column.

## 6. Querying CTEs

Open `models/intermediate/int_bet_markets.sql`. Highlight the `markets` CTE and
run it inline with dbt Fusion.

"I can inspect intermediate logic without building the whole project."

## 7. dbt run as tables

"Now materialize as tables. This is a point-in-time snapshot."

In `dbt_project.yml`, use:

```yaml
+materialized: table
```

Run:

```sh
dbt run
```

Query `clickstream.fct_market_odds`, then run `scripts/count_bets.sh`. The
source count changes, but the mart table stays fixed until the next dbt run.

## 8. Materialized views

"Now for the ClickHouse-specific path."

In `dbt_project.yml`, use:

```yaml
+materialized: materialized_view
```

Run:

```sh
dbt run
```

Query twice about 10 seconds apart:

```sql
select
    market_id,
    side,
    sum(bet_count) as bet_count,
    sum(total_amount) as total_amount,
    round(sum(avg_implied_prob * bet_count) / sum(bet_count), 4) as avg_implied_prob,
    max(latest_bet_at) as latest_bet_at
from clickstream.fct_market_odds
group by market_id, side
order by total_amount desc
limit 10
```

"The dbt model created a target table plus a generated ClickHouse materialized
view. New bets keep flowing into the target without another dbt run."
