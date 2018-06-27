select
  s.id as subscription_id
  , s.customer_id
  , s.metadata_user_id as user_id
  , s.plan_id
  , s.simplified_plan_id
  , s.canceled_at
  , s.created_at
  , s.quantity
  , s.trial_start_at
  , s.trial_end_at
  , count(distinct case when c.captured and c.paid and c.refunded = false then c.id else null end) as successful_charges
  , count(distinct case when c.refunded then c.id else null end) as refunded_charges
  , count(distinct case when c.paid = false and c.captured = false then c.id else null end) as failed_charges
  , case
    when canceled_at between '{{ var('t') }}' and dateadd(month, 2, '{{ var('t') }}') then True
    else False
    end as churned_in_next_two_months
from dbt.stripe_subscriptions as s
join dbt.stripe_invoices as i -- join invoices and charges created before Dec 31
  on i.subscription_id = s.id
  and i.paid
  and i.amount_due is not null
  and i.amount_due > 0
  and i.date < '{{ var('t') }}'
join dbt.stripe_charges as c
  on c.invoice = i.id
  and c.amount is not null
  and c.amount > 0
  and c.created < '{{ var('t') }}'
where
  s.billing_interval = 'month' -- only include monthly subscriptions created after Jan 1, 2017
  and s.simplified_plan_id != 'reply' -- only want publish subscriptions
  and s.simplified_plan_id != 'analyze'
  and s.created_at between dateadd(year, -1, '{{ var('t') }}') and '{{ var('t') }}'
  and (s.canceled_at > '{{ var('t') }}' or s.canceled_at is null)
  -- only want subscriptions with at least one successful charge
  and s.successful_charges >= 1
{{ dbt_utils.group_by(n=10) }}
