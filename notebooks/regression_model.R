# load libraries
library(buffer)
library(dplyr)
library(tidyr)
library(lubridate)


# get helper functions
source("~/Documents/GitHub/churnado/notebooks/churnado_features.R")

# read data from csv
#get_data <- function() {
#  
#  print("Reading data.")
#  
#  df <- read.csv('~/Documents/GitHub/churnado/data/features.csv', header = T)
#  df
#  
#}


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
  features <- c('has_team_member', 'is_mobile_user', 'has_refunded_charge', 
                'has_failed_charge', 'updates_last_week', 'weeks_with_updates',
                'simplified_plan_id', 'subscription_age', 'has_billing_actions', 'has_analytics_actions')
  
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
  new_data$pred <- predict(model, newdata = new_data, type = "response")
  
  # set the date
  new_data$prediction_created_at <- Sys.time()
  
  # return new data with predictions
  new_data
}


main <- function() {
  
  # set training date
  training_date <- '2017-12-31'
  
  # get data and clean it
  df <- get_data(training_date)
  df <- clean_data(df)
  
  # build model
  mod <- build_model(df)
  
  # make predictions
  predictions <- make_predictions(mod, df)
  
  # write results to Redshift
  print("Writing to Redshift.")
  buffer::write_to_redshift(predictions, "churnado_predictions", "churnado-predictions",
                            option = "replace", keys = c("subscription_id", "prediction_created_at"))
  print("Done.")
}

main()

# unload lubridate package
detach("package:lubridate", unload = TRUE)
