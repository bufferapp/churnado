Single Variable Models
================

The purpose of this notebook is to explore single variable models and determine which features correlate best with the likelihood of churning. The first thing we'll need to do is gather the data from the `data` directory.

``` r
# read data from csv
subs <- read.csv('../data/features.csv', header = T)
```

Great, we have 74 thousand subscriptions to work with. To evaluate our models, we'll need to split our data into a training and testing set.

``` r
# set seed for reproducible results
set.seed(2356)

# set random groups
subs$rgroup <- runif(dim(subs)[[1]])

# split out training and testing sets
training <- subset(subs, rgroup <= 0.8)
testing <- subset(subs, rgroup > 0.8)
```

Great, 80% of our data was put into a training set and the remaining 20% in a testing set.

### Single Variable Models

Next we'll need to define some functions that will help us make predictions and calculate area under the curve (AUC). The code has been hidded but is available in the .Rmd file.

We'll loop through the categorical variables and make predictions. Once the predictions are made, we calculate AUC on the training and testing sets.

``` r
# identify categorical varaibles
catVars <- c('signup_option', 'is_mobile_user', 'billing_interval', 'country', 'simplified_plan_name',
             'signup_client_name')

# loop through categorical varaibles and mkae predictions
for(v in catVars) {

  # Make prediction for each categorical variable
  pi <- paste('pred', v, sep='_')

  # Do it for the training and testing datasets
  training[, pi] <- make_prediction_categorical(training[, "did_churn"],
                                               training[, v], training[,v])

  testing[, pi] <- make_prediction_categorical(training[, "did_churn"],
                                               training[, v], testing[,v])
}
```

For each level of the categorical levels, we have the predicted likelihood of a user churning. This is just the proportion of users that churned in each segment.

``` r
# calculate AUC for each
for(v in catVars) {

  # Name the prediction variables
  pi <- paste('pred', v, sep = '_')

  # Find the AUC of the variable on the training set
  aucTrain <- calcAUC(training[, pi], training[, "did_churn"])

  # Find the AUC of the variable on the testing set
  aucTest <- calcAUC(testing[, pi], testing[, "did_churn"])

  # Print the results
  print(sprintf("%s, trainAUC: %4.3f testingAUC: %4.3f", pi, aucTrain, aucTest))

}
```

    ## [1] "pred_signup_option, trainAUC: 0.448 testingAUC: 0.451"
    ## [1] "pred_is_mobile_user, trainAUC: 0.500 testingAUC: 0.500"
    ## [1] "pred_billing_interval, trainAUC: 0.412 testingAUC: 0.423"
    ## [1] "pred_country, trainAUC: 0.456 testingAUC: 0.491"
    ## [1] "pred_simplified_plan_name, trainAUC: 0.487 testingAUC: 0.487"
    ## [1] "pred_signup_client_name, trainAUC: 0.455 testingAUC: 0.465"

These single variable models aren't any better than random guesses unfortunately. Let's loop through the numeric variables now. The predictions are made by essentially turning the numeric variables into categorical variables by creating "bins". There are a lot of numeric variables.

``` r
# define numeric variables
numVars <- c('number_of_profiles', 'number_of_twitter_profiles', 'number_of_facebook_personal_profiles',
             'number_of_facebook_pages', 'number_of_facebook_groups', 'number_of_instagram_personal_profiles',
             'number_of_instagram_business_profiles', 'number_of_successful_charges',
             'number_of_failed_charges', 'number_of_refunded_charges', 'days_since_last_update',
             'weeks_with_updates', 'total_updates', 'updates_per_week', 'estimate', 'subscription_age')

# loop through the columns and apply the formula
for(v in numVars) {

  # name the prediction column
  pi <- paste('pred', v, sep = '_')

  # Make predictions
  training[, pi] <- make_prediction_numeric(training[, "did_churn"],
                                               training[, v], training[,v])

  testing[, pi] <- make_prediction_numeric(training[, "did_churn"],
                                               training[, v], testing[,v])


 # Find the AUC of the variable on the training set
  aucTrain <- calcAUC(training[, pi], training[, "did_churn"])

  # Find the AUC of the variable on the testing set
  aucTest <- calcAUC(testing[, pi], testing[, "did_churn"])

  # Print the results
  print(sprintf("%s, trainAUC: %4.3f testingAUC: %4.3f", pi, aucTrain, aucTest))

}
```

    ## [1] "pred_number_of_profiles, trainAUC: 0.464 testingAUC: 0.482"
    ## [1] "pred_number_of_twitter_profiles, trainAUC: 0.336 testingAUC: 0.337"
    ## [1] "pred_number_of_facebook_personal_profiles, trainAUC: 0.459 testingAUC: 0.460"
    ## [1] "pred_number_of_facebook_pages, trainAUC: 0.345 testingAUC: 0.345"
    ## [1] "pred_number_of_facebook_groups, trainAUC: 0.481 testingAUC: 0.481"
    ## [1] "pred_number_of_instagram_personal_profiles, trainAUC: 0.474 testingAUC: 0.475"
    ## [1] "pred_number_of_instagram_business_profiles, trainAUC: 0.437 testingAUC: 0.437"
    ## [1] "pred_number_of_successful_charges, trainAUC: 0.392 testingAUC: 0.408"
    ## [1] "pred_number_of_failed_charges, trainAUC: 0.462 testingAUC: 0.465"
    ## [1] "pred_number_of_refunded_charges, trainAUC: 0.470 testingAUC: 0.474"
    ## [1] "pred_days_since_last_update, trainAUC: 0.372 testingAUC: 0.360"
    ## [1] "pred_weeks_with_updates, trainAUC: 0.374 testingAUC: 0.366"
    ## [1] "pred_total_updates, trainAUC: 0.380 testingAUC: 0.368"
    ## [1] "pred_updates_per_week, trainAUC: 0.380 testingAUC: 0.368"
    ## [1] "pred_estimate, trainAUC: 0.405 testingAUC: 0.399"
    ## [1] "pred_subscription_age, trainAUC: 0.369 testingAUC: 0.385"

All of these single variable models perform very poorly. None do any better than random guessing. It seems like the variance in the response cannot be explained sufficiently by any single variable in our dataset. Makes sense.
