select
   s.*
   , {{ dbt_utils.star(from=ref('churnado_user_features'), except=["user_id"]) }}
from {{ ref('churnado_subscriptions') }} as s
join {{ ref('churnado_user_features') }} as u on u.user_id = s.user_id
