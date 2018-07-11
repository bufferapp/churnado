{{
  config({
    "sort": "user_id",
    "dist": "user_id",
  })
}}

select
  a.user_id
  , count(distinct case when full_scope like 'dashboard settings billing%' then id else null end) as billing_actions
  , count(distinct case when full_scope like 'dashboard analytics%' then id else null end) as analytics_actions
  , count(distinct case when full_scope like 'dashboard settings billing%' then date_trunc('week', a.created_at) else null end) as number_of_weeks_with_actions
from dbt.actions_taken as a
join {{ ref('churnado_subscriptions') }} as s on a.user_id = s.user_id
where a.created_at between dateadd(week, -8, '{{ var('t') }}') and '{{ var('t') }}'
group by 1
