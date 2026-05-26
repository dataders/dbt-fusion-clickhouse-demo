select
    bet_id,
    user_id,
    placed_at,
    placed_date,
    market_id,
    side,
    amount,
    implied_prob,
    channel,
    region,
    ingest_time
from {{ source('clickstream', 'bets') }}
