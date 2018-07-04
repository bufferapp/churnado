select
  up.user_id
  , date(date_trunc('week', up.created_at)) as week
  , datediff(week, dateadd(week, -8, '{{ var('t') }}'), date_trunc('week', up.created_at)) as week_number
  , count(distinct up.id) as number_of_updates
  , count(distinct date(up.created_at)) as number_of_days_with_updates
  , count(distinct date_trunc('week', up.created_at)) as number_of_weeks_with_updates
  , count(distinct case when up.client_type = 'Extension' then up.id else null end) as number_of_extension_updates
  , coalesce(count(distinct e.id), 0) as number_of_update_errors
from dbt.updates as up
join {{ ref('churnado_subscriptions') }} as s on up.user_id = s.user_id
left join dbt.update_errors as e on e.update_id = up.id
-- only want updates created in an 8-week time window
where up.created_at between dateadd(week, -8, '{{ var('t') }}') and '{{ var('t') }}'
group by 1, 2, 3
