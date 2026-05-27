with bets as (
    select * from {{ ref('stg_bets') }}
),

markets as (
    select * from {{ ref('stg_markets') }}
)

select
    bets.bet_id,
    bets.user_id,
    bets.placed_at,
    bets.placed_date,
    bets.market_id,
    bets.side,
    bets.amount,
    bets.implied_prob,
    bets.channel,
    bets.region,
    bets.ingest_time,
    markets.question,
    markets.category,
    markets.close_date,
    markets.initial_yes_prob
from bets
left join markets
    on bets.market_id = markets.market_id
