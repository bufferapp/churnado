select
  a.user_id
  , count(distinct case when a.full_scope like 'dashboard settings billing%' then a.id else null end) as billing_actions
  , count(distinct case when a.full_scope like 'dashboard analytics%' then a.id else null end) as analytics_actions
  , count(distinct date(a.created_at)) as number_of_days_with_actions
  , count(distinct date_trunc('week', a.created_at)) as number_of_weeks_with_actions
from dbt.actions_taken as a
where a.created_at >= dateadd(week, -8, '{{ var('t') }}')
and a.created_at <= '{{ var('t') }}'
group by 1
