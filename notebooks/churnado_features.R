# load libraries
library(buffer)
library(dplyr)
library(tidyr)
library(dbplyr)
library(purrr)
library(broom)
library(lubridate)


# get subscriptions
get_subscriptions <- function(training_date) {
  
  # connect to redshift
  con <- redshift_connect()
  
  # query to get subscriptions
  subscription_query <- "
  
    select
      s.id as subscription_id
      , u.id as user_id
      , s.customer_id
      , s.plan_id
      , s.simplified_plan_id
      , s.canceled_at
      , s.created_at
      , count(distinct case when c.captured and c.paid and c.refunded = false then c.id else null end) as successful_charges
      , count(distinct case when c.refunded then c.id else null end) as refunded_charges
      , count(distinct case when c.paid = false and c.captured = false then c.id else null end) as failed_charges
      , case
          when s.canceled_at between '%s' and dateadd(month, 2, '%s') then True
          else False
        end as did_churn
    from dbt.stripe_subscriptions as s
    join dbt.users as u on u.billing_stripe_customer_id = s.customer_id
    join dbt.stripe_invoices as i
    on i.subscription_id = s.id
    and i.paid
    and i.amount_due is not null
    and i.amount_due > 0
    and i.date < '%s'
    join dbt.stripe_charges as c
    on c.invoice = i.id
    and c.amount is not null
    and c.amount > 0
    and c.created < '%s'
    where s.billing_interval = 'month'
    and (s.simplified_plan_id = 'awesome' or s.simplified_plan_id = 'business')
    and s.created_at between dateadd(year, -1, '%s') and '%s'
    and (s.canceled_at > '%s' or s.canceled_at is null)
    and s.successful_charges >= 1
    group by 1,2,3,4,5,6,7
  "
  
  # get full subscription query
  final_subscription_query <- do.call("sprintf", as.list(c(subscription_query, rep(training_date, 7))))
  
  # query redshift
  subs <- query_db(final_subscription_query, con)
  subs
  
}


get_users <- function(user_ids) {
  
  
  # connect to redshift
  con <- redshift_connect()
  
  # users query
  users_query <- "
  
    with user_team_member_facts as (
      select
        owner_user_id as org_owner_user_id
        , count(distinct case when team_member_user_id != owner_user_id then team_member_user_id else null end) as team_members
      from dbt.org_team_members
      group by 1
    )
    select 
      u.id as user_id
      , u.billing_stripe_customer_id as customer_id
      , date(u.created_at) as signup_date
      , case when ut.team_members is not null and ut.team_members >= 1 then True 
          else false
          end as has_team_member
      , case when uc.is_ios_user or uc.is_android_user then True else False end as is_mobile_user
    from dbt.users as u
    left join user_team_member_facts as ut on ut.org_owner_user_id = u.id
    left join looker_scratch.LR$MCC6J330P1RKDPL9M3KAH_user_client_facts as uc
      on u.id = uc.user_id
    where user_id in user_id_list
    group by 1,2,3,4,5
    "
  
  # final users query
  final_users_query <- gsub("user_id_list", user_ids, users_query)
  
  # query redshift
  users <- query_db(final_users_query, con)
  users
}


# function to get user IDs from subs dataframe
get_user_ids <- function(subs_df) {
  
  # get user ids from subs dataframe
  user_ids <- build_sql(subs_df$user_id)
  
  user_ids
  
}


get_updates_data <- function(user_ids, training_date) {
  
  # connect to redshift
  con <- redshift_connect()
  
  # updates query
  updates_query <- "
                          
    select
      user_id
      , date(date_trunc('week', created_at)) as week
      , count(distinct id) as updates
    from dbt.updates
    where user_id in user_id_list
    and was_sent_with_buffer
    and created_at >= dateadd(week, -10, '%s') and created_at <= '%s'
    group by 1, 2

  "
  
  # final updates query
  final_updates_query <- gsub("user_id_list", user_ids, sprintf(updates_query, training_date, training_date))
  
  # query redshift
  updates <- query_db(final_updates_query, con)
  
  # complete the updates dataframe
  updates <- updates %>%
    mutate(updates = as.integer(updates)) %>% 
    filter(week != max(week) & week != min(week)) %>%
    complete(user_id, week, fill = list(updates = 0))
  
  last_week <- max(updates$week)
  
  # group by user
  by_user <- updates %>% 
    group_by(user_id) %>% 
    summarise(weeks_with_updates = length(updates[updates > 0]),
              total_updates = sum(updates),
              updates_last_week = sum(updates[week == last_week]))
  
  by_user
  
}

get_last_update_date <- function(user_ids, training_date) {
  
  # connect to redshift
  con <- redshift_connect()
  
  # last update query
  last_update_query <- "
                             
    with last_update_date as (
      select
        user_id
        , max(created_at) as last_update_date
      from dbt.updates
      where user_id in user_id_list
      and was_sent_with_buffer
      and created_at <= date('%s')
      group by 1
    )
    select
      user_id
      , datediff(days, last_update_date, date('%s')) as days_since_last_update
    from last_update_date
    "
  
  # final query
  final_query <- gsub("user_id_list", user_ids, sprintf(last_update_query, training_date, training_date))
  
  # query redshift
  last_update <- query_db(final_query, con)
  
  # set count as integer
  last_update <- last_update %>% 
    mutate(days_since_last_update = as.integer(days_since_last_update))
  
  last_update
}


get_billing_actions <- function(user_ids, training_date) {
  
  # connect to redshift
  con <- redshift_connect()
  
  # get query
  billing_query <- "
  
    select
      a.user_id
      , count(distinct case when full_scope = 'dashboard settings billing viewed' then id else null end) as billing_actions
      , count(distinct case when full_scope = 'dashboard analytics posts viewed' then id else null end) as analytics_actions
      , count(distinct case when full_scope = 'dashboard settings billing viewed' then date_trunc('week', a.created_at) else null end) as number_of_weeks_with_actions
    from dbt.actions_taken as a
    where a.user_id in user_id_list
    and a.created_at between dateadd(week, -8, '%s') and '%s'
    group by 1  
  "
  
  # final query
  final_query <- gsub("user_id_list", user_ids, sprintf(billing_query, training_date, training_date))
  
  # query redshift
  billing_actions <- query_db(final_query, con)
  
  # fix integers
  billing_actions$billing_actions <- as.integer(billing_actions$billing_actions)
  billing_actions$analytics_actions <- as.integer(billing_actions$analytics_actions)
  billing_actions$number_of_weeks_with_actions <- as.integer(billing_actions$number_of_weeks_with_actions)
  
  billing_actions
}


get_data <- function(training_date) {
  
  # get subscriptions
  print('Getting subscriptions.')
  subs <- get_subscriptions(training_date)
  
  # get user IDs
  print('Getting user IDs')
  user_ids <- get_user_ids(subs)
  
  # get users
  print('Getting user data.')
  users <- get_users(user_ids)
  
  # get updates data
  print('Getting updates data.')
  updates <- get_updates_data(user_ids, training_date)
  
  # get last update date
  print('Getting last update date')
  last_updates <- get_last_update_date(user_ids, training_date)
  
  # get billing actions
  print('Getting billing actions')
  billing_actions <- get_billing_actions(user_ids, training_date)
  
  # join all the datasets together
  features <- subs %>% 
    inner_join(select(users, -customer_id), by = "user_id") %>% 
    left_join(updates, by = "user_id") %>% 
    left_join(last_updates, by = "user_id") %>% 
    left_join(billing_actions, by = "user_id")
  
  # fix integer types
  features <- features %>% 
    mutate(successful_charges = as.integer(successful_charges),
           failed_charges = as.integer(failed_charges),
           refunded_charges = as.integer(refunded_charges),
           created_at = as.Date(created_at, format = "%Y-%m-%d"),
           canceled_at = as.Date(canceled_at, format = "%Y-%m-%d"))
  
  # replace NAs with 0s
  features$weeks_with_updates[is.na(features$weeks_with_updates)] <- 0
  features$total_updates[is.na(features$total_updates)] <- 0
  features$days_since_last_update[is.na(features$days_since_last_update)] <- 0
  features$updates_last_week[is.na(features$updates_last_week)] <- 0
  features$billing_actions[is.na(features$billing_actions)] <- 0
  features$analytics_actions[is.na(features$analytics_actions)] <- 0
  features$number_of_weeks_with_actions[is.na(features$number_of_weeks_with_actions)] <- 0
  
  # create dummy variables
  features <- features %>% 
    mutate(has_billing_actions = as.factor(billing_actions > 0),
           has_analytics_actions = as.factor(analytics_actions > 0))
  
  features
}

# unload lubridate package
detach("package:lubridate", unload = TRUE)
