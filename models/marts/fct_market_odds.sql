select
    market_id,
    any(question) as question,
    any(category) as category,
    side,
    count() as bet_count,
    sum(amount) as total_amount,
    avg(implied_prob) as avg_implied_prob,
    max(placed_at) as latest_bet_at
from {{ ref('int_bet_markets') }}
group by
    market_id,
    side
