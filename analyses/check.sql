
select
count(*)
from {{ ref('fct_market_odds') }}
