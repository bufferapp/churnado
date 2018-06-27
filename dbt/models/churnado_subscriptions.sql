select
  s.id as subscription_id
  , s.customer_id
  , s.plan_id
  , s.simplified_plan_id
  , s.canceled_at
  , s.created_at
  , s.quantity
  , s.trial_start_at
  , s.trial_end_at
  , u.id as user_id
  , case -- if subscription was active on Dec 31 and was created two months before, we can use it in the training set
      when s.created_at < '2017-11-01' and (s.canceled_at is null or s.canceled_at > '2017-12-31')
      then true
      else false
    end as is_training
  , count(distinct case when c.captured and c.paid and c.refunded = false then c.id else null end) as successful_charges
  , count(distinct case when c.refunded then c.id else null end) as refunded_charges
  , count(distinct case when c.paid = false and c.captured = false then c.id else null end) as failed_charges
from dbt.stripe_subscriptions as s
inner join dbt.users as u
  on s.customer_id = u.billing_stripe_customer_id
left join dbt.stripe_invoices as i -- join invoices and charges created before Dec 31
  on i.subscription_id = s.id
  and i.paid
  and i.amount_due is not null
  and i.amount_due > 0
  and i.date <= '2017-12-31'
left join dbt.stripe_charges as c
  on c.invoice = i.id
  and c.amount is not null
  and c.amount > 0
  and c.created <= '2017-12-31'
where
  s.billing_interval = 'month' -- only include monthly subscriptions created after Jan 1, 2017
  and s.simplified_plan_id != 'reply' -- only want publish subscriptions
  and s.simplified_plan_id != 'analyze'
  and s.created_at between '2017-01-01' and '2018-02-01'
  and s.successful_charges >= 1 -- only want subscriptions with at least one successful charge
group by 1,2,3,4,5,6,7,8,9,10,11,12
