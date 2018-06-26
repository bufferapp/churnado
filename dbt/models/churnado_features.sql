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
    , case when created_at < '2018-01-01' then True else False end as is_training
from dbt.stripe_subscriptions
where
    billing_interval = 'month'
    and created_at between '2017-01-01' and '2018-02-01'
    and user_id is not null
