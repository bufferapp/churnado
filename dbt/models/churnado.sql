select
  customer
  , min(created) as first_payment
  , max(created) as last_payment
from stripe._charges
where
  not refunded
  and paid
  and amount = 1000
group by customer
