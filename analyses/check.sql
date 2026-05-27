
select
count(*)
from {{ ref('int_bet_markets') }}
