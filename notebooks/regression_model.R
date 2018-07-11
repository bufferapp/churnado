# load libraries
library(buffer)
library(dplyr)
library(ggplot2)
library(hrbrthemes)
library(scales)
library(tidyr)
library(lubridate)
library(broom)
library(purrr)

# read data from csv
get_data <- function() {
  
  print("Reading data.")
  
  df <- read.csv('~/Documents/GitHub/churnado/data/features.csv', header = T)
  df
  
}


# clean data
clean_data <- function(df) {
  
  print("Cleaning data.")
  
  # remove yearly dfcriptions 
  df <- filter(df, billing_interval == 'month' & 
                   (simplified_plan_name == 'awesome' | simplified_plan_name == 'business'))
  
  # set dates
  df$created_at <- as.Date(df$created_at, format = '%Y-%m-%d')
  df$canceled_at <- as.Date(df$canceled_at, format = '%Y-%m-%d')
  df$signup_date <- as.Date(df$signup_date, format = '%Y-%m-%d')
  
  # update variables
  df <- df %>% 
    mutate(user_age = as.numeric(created_at - signup_date),
           did_churn = ifelse(did_churn, 1, 0),
           is_idle = as.factor(is_idle))
  
  # return cleaned dataframe
  df
  
}


# build regression model
build_model <- function(df) {
  
  print("Building model.")
  
  # list features
  features <- c('has_team_member', 'is_mobile_user', 'has_refunded_charge', 
                'has_failed_charge', 'updates_past_week', 'weeks_with_updates',
                'estimate', 'simplified_plan_name', 'subscription_age',
                'has_billing_actions', 'has_analytics_actions')
  
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
  
  # get data and clean it
  df <- get_data()
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
