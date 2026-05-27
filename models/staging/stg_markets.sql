{{ config(order_by=['market_id']) }}

select
    assumeNotNull(market_id) as market_id,
    assumeNotNull(question) as question,
    assumeNotNull(category) as category,
    toDate(assumeNotNull(close_date)) as close_date,
    toFloat32(assumeNotNull(initial_yes_prob)) as initial_yes_prob
from {{ ref('markets') }}
