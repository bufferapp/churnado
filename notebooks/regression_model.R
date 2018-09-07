# load libraries
library(buffer)
library(dplyr)
library(digest)


# get helper functions
source("~/Documents/GitHub/churnado/notebooks/churnado_features.R")


# clean data
clean_data <- function(df) {
  
  print("Cleaning data.")
  
  # remove yearly dfcriptions 
  df <- filter(df, simplified_plan_id == 'awesome' | simplified_plan_id == 'business')
  
  # set dates
  df$created_at <- as.Date(df$created_at, format = '%Y-%m-%d')
  df$canceled_at <- as.Date(df$canceled_at, format = '%Y-%m-%d')
  df$signup_date <- as.Date(df$signup_date, format = '%Y-%m-%d')
  
  # update variables
  df <- df %>% 
    mutate(user_age = as.numeric(created_at - signup_date),
           subscription_age = as.numeric(as.Date('2017-12-31') - created_at),
           has_refunded_charge = as.factor(refunded_charges > 0),
           has_failed_charge = as.factor(failed_charges > 0),
           did_churn = ifelse(did_churn, 1, 0))
  
  # return cleaned dataframe
  df
  
}


# build regression model
build_model <- function(df) {
  
  print("Building model.")
  
  # list features
  features <- c('has_team_member', 'is_mobile_user', 'has_refunded_charge', 'successful_charges',
                'has_failed_charge', 'updates_last_week', 'total_updates', 'weeks_with_updates',
                'user_age', 'has_billing_actions', 'number_of_weeks_with_actions', 'days_since_last_update')
  
  # collapse list to string
  feature_string <- paste(features, collapse = ' + ')
  
  # model formula
  formula <- paste0('did_churn ~ ', feature_string)
  
  # second model
  mod <- glm(formula = formula, data = df, family = binomial(link = "logit"))
  
  # return model
  mod
}


# make predictions
make_predictions <- function(model, new_data) {
  
  print("Making predictions.")
  
  # make predictions
  new_data$churn_probability <- predict(model, newdata = new_data, type = "response")
  
  # isolate subscription id and prediction
  predictions <- new_data %>% 
    select(subscription_id, churn_probability) %>% 
    mutate(created_at = Sys.time(),
           churn_probability = round(churn_probability, 2),
           model_name = 'logistic_regression',
           model_version = '0.1',
           id = paste0(as.character(subscription_id), as.character(churn_probability),
                       as.character(created_at), model_name, model_version))
  
  # return new data with predictions
  predictions
}


main <- function() {
  
  # set training date
  training_date <- '2018-06-01'
  
  # get data and clean it
  df <- get_data(training_date)
  df <- clean_data(df)
  
  # write features to redshift
  churnado_features <- df %>% 
    select(-did_churn) %>% 
    mutate(features_created_at = Sys.time())
  
  buffer::write_to_redshift(df = churnado_features, 
                            table_name = "churnado_features", 
                            bucket_name = "churnado-features",
                            option = "upsert", 
                            keys = c("subscription_id"))
  
  # build model
  mod <- build_model(df)
  
  # make predictions
  predictions <- make_predictions(mod, df)
  
  # write results to Redshift
  print("Writing to Redshift.")
  buffer::write_to_redshift(df = predictions, 
                            table_name = "churnado_predictions", 
                            bucket_name = "churnado-predictions",
                            option = "upsert", 
                            keys = c("id"))
  print("Done.")
}

main()

# unload lubridate package
detach("package:lubridate", unload = TRUE)
