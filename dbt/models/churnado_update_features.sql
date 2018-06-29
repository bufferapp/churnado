select
  u.id as user_id
  , date(date_trunc('week', up.created_at)) as week
  , datediff(week, dateadd(week, -8, '{{ var('t') }}'), date_trunc('week', up.created_at)) as week_number
  , count(distinct up.id) as number_of_updates
  , count(distinct date(up.created_at)) as number_of_days_with_updates
  , count(distinct date_trunc('week', up.created_at)) as number_of_weeks_with_updates
  , count(distinct case when up.client_type = 'Extension' then up.id else null end) as number_of_extension_updates
  , count(distinct p.id) as number_of_profiles
  , coalesce(count(distinct e.id), 0) as number_of_update_errors
from dbt.users as u
join dbt.profiles as p
  on u.id = p.user_id
join dbt.updates as up
  on p.id = up.profile_id
  -- only want updates created in Buffer (or do we?)
  and up.was_sent_with_buffer
  -- only want updates created in an 8-week time window
  and up.created_at >= dateadd(week, -8, '{{ var('t') }}')
  and up.created_at <= '{{ var('t') }}'
left join dbt.update_errors as e
  on e.update_id = up.id
group by 1, 2, 3
