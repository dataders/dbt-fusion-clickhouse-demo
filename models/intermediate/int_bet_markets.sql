with bets as (
    select * from {{ ref('stg_bets') }}
),

markets as (
    select
        market_id,
        question,
        category,
        toDate(close_date) as close_date,
        toFloat32(initial_yes_prob) as initial_yes_prob
    from {{ ref('markets') }}
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
