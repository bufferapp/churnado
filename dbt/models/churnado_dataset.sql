select
   s.*
   , {{ dbt_utils.star(from=ref('churnado_user_features'), except=["user_id"]) }}
   , {{ dbt_utils.star(from=ref('churnado_actions_features'), except=["user_id"]) }}
   , {{ dbt_utils.star(from=ref('churnado_update_features'), except=["user_id"]) }}
from {{ ref('churnado_subscriptions') }} as s
join {{ ref('churnado_user_features') }} as u on u.user_id = s.user_id
left join {{ ref('churnado_actions_features') }} as a on a.user_id = s.user_id
left join {{ ref('churnado_update_features') }} as up on up.user_id = s.user_id
