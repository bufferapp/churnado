with subscription_info as (
    select
        id as subscription_id
        , customer_id
        , plan_id
        , simplified_plan_id
        , canceled_at
        , created_at
        , quantity
        , trial_start_at
        , trial_end_at
        , metadata_trial_type
        , successful_charges
        , refunded_charges
        , failed_charges
        , metadata_user_id as user_id
        , datediff(day, trial_start_at, trial_end_at) as trial_lenght_days
        , datediff(day, created_at, coalesce(canceled_at, '2018-01-01')) as subscription_lenght
    from dbt.stripe_subscriptions
    where
        billing_interval = 'month'
        and status != 'past_due'
        and created_at between '2017-01-01' and '2018-01-01'
        and user_id is not null

), subscription_churn as (
select
  *
  , case when subscription_lenght between 60 and 89 and canceled_at is not null then True else False end as churn_at_next_month
from subscription_info

)
select
  subscription_churn.*
  , u.created_at as signup_date
  , u.locale_browser_language
  , u.is_suspended
  , u.is_approved
  , u.has_notifications_enabled
  , u.has_verified_email
  , u.timezone
  , u.twofactor_type
  , u.number_of_bonus_profiles
  , u.number_of_bonus_team_members
  , u.number_of_default_profiles
  , u.number_of_password_resets
from subscription_churn
join dbt.users as u on u.id = subscription_churn.user_id
