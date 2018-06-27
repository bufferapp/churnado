select
  u.id as user_id
  , u.created_at as user_signup_date
  , locale_browser_language
  , is_suspended
  , is_approved
  , has_notifications_enabled
  , has_verified_email
  , timezone
  , twofactor_type
  , number_of_bonus_profiles
  , number_of_bonus_team_members
  , number_of_default_profiles
  , number_of_password_resets
from dbt.users as u
join {{ ref('churnado_subscriptions') }} as s on u.id = s.user_id
