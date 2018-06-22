Logistic Regression Models
================

The purpose of this notebook is to explore logistic regression models to establish a baseline model performance and determine which features correlate best with the likelihood of churning. The final model identifies a set of potential at-risk subscriptions that finds about 55% of all the true at-risk subscriptions, with a true positive rate around 68% higher than the overall population rate. The AUC calculated on the testing set is **0.68**.

The first thing we'll need to do is gather the data from the `data` directory.

``` r
# read data from csv
subs <- read.csv('data/features.csv', header = T)
```

Great, we have 74 thousand subscriptions to work with. To evaluate our models, we'll need to split our data into a training and testing set. Fist, let's simplify by removing subscriptions billed annually.

``` r
# remove yearly subscriptions 
subs <- filter(subs, billing_interval == 'month')
```

Exploratory Analysis
--------------------

We'll want to be selective with the features we use in our model, so let's do some exploratory analysis to see what's going on with the features. We'll start by looking at the total number of updates sent.

### Updates

Let's look at how the number of updates is distributed.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-4-1.png)

We can see that a greater proportion of churned users had zero updates between October 15, 2017 and January 1, 2018. Both of these distributions appear to be power-law distributed, so it may make sense to apply a transformation. A log transformation would make sense, but we need to figure out what to do with the zeroes. One approach would be to take `log(updates + 1)`, which would conveniently map the zeroes to 0. Let's try it.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-5-1.png)

Interesting, we can see that users that churned seem to have less updates. What if we removed users with zero updates altogether?

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-6-1.png)

This looks better. Now let's graph the growth coefficients of updates per week for churned and non-churned users.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-7-1.png)

That's interesting. A much higher percentage of churned users had a growth coefficient of zero, probably because they had no updates in the time period.

Let's take a look at the number of weeks in which users sent updates.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-8-1.png)

This is useful to see. A higher percentage of users that *didn't* churn created updates in all 8 weeks. A higher percentage of users that did churn didn't create updates in any of the weeks. It should be useful to include this feature in the final model. It may even make sense to use it as a *categorical* variable.

``` r
# set weeks with updates as categorical
subs <- subs %>% 
  mutate(weeks_with_updates = as.factor(weeks_with_updates))
```

Let's shift and have a look at profiles.

### Profiles

We'll visualize the distribution of the number of profiles users have. I'm guessing that this won't be too useful of a feature, but let's see.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-10-1.png)

Cool, let's apply a log transformation here because the data is so skewed.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-11-1.png)

These distributions look very similar, which is what we expected. I don't think that this will be an especially helpful feature to include in the model. Let's compare churn rates of users that have used the mobile apps to that of users that did not.

### Mobile Users

Let's see if there is any correlation between churn and whether the user was a mobile user.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-12-1.png)

It seems that there is a correlation there. Users that used one of the mobile apps churned at a significantly lower rate. That's cool. Let's look at the subscription age now.

### Subscription Age

Let's create the double density plot.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-13-1.png)

This is interesting. It seems like a higher percentage of churned subscriptions were "younger". If we normalize this metric we can see that more clearly.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-14-1.png)

Now let's look at the number of days since the user's last update.

### Days Since Last Update

We'll create another double density plot to compare the metrics for churned and non-churned subscriptions.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-15-1.png)

This is great, we can see that a much higher percentage of non-churned users created an update on the last day, signalling that they were active on the last day. Let's visualize this again with a CDF.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-16-1.png)

This is good. We might also create a categorical variable that indicates whether the user created an update in the most recent 4 days.

``` r
# create new variable
subs <- subs %>% 
  mutate(update_past_four_days = days_since_last_update <= 4)
```

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-18-1.png)

Perfect. Now let's take a look at team members.

### Team Members

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-19-1.png)

This isn't helpful. Let's created a categorical variable that indicates whether or not a user has a team member.

``` r
# create categorical team member variable
subs <- subs %>% 
  mutate(has_team_member = number_of_team_members >= 1)
```

Now let's take a look at the numebr of charges that subscriptions had.

### Failed Charges

We'll start by looking at the number of failed charges that customers had.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-21-1.png)

This isn't helpful. Let's create a categorical variable that tells us if the customer had any failed charges. We'll do the same for refunded charges.

``` r
# create new feature
subs <- subs %>% 
  mutate(has_failed_charge = number_of_failed_charges >= 1,
         has_refunded_charge = number_of_refunded_charges >= 1)
```

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-23-1.png)

Huh, that is counterintuitive, but there does appear to be a difference there.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-24-1.png)

Wait, what? It seems that if a customer had a refunded charge they may be *less* likely to churn. This is counterintuitive, but may be useful in our model.

Data Partitioning
-----------------

Now let's split our data into training and testing sets.

``` r
# change values of did_churn
subs <- subs %>% 
  filter(simplified_plan_name != 'reply') %>% 
  mutate(did_churn = ifelse(did_churn, 1, 0))

# set seed for reproducible results
set.seed(2356)

# set random groups
subs$rgroup <- runif(dim(subs)[[1]])

# split out training and testing sets
training <- subset(subs, rgroup <= 0.8)
testing <- subset(subs, rgroup > 0.8)
```

Great, 80% of our data was put into a training set and the remaining 20% in a testing set. Now let's build our regression model.

### Logistic Regression

First we'll need to decide which features to include in our model.

``` r
# list features
features <- c('has_team_member', 'is_mobile_user', 'number_of_profiles', 'has_refunded_charge',
              'has_failed_charge', 'update_past_four_days', 'estimate', 'weeks_with_updates',
              'estimate', 'total_updates', 'simplified_plan_name', 'subscription_age')

# collapse list to string
feature_string <- paste(features, collapse = ' + ')

# model formula
formula <- paste0('did_churn ~ ', feature_string)
formula
```

    ## [1] "did_churn ~ has_team_member + is_mobile_user + number_of_profiles + has_refunded_charge + has_failed_charge + update_past_four_days + estimate + weeks_with_updates + estimate + total_updates + simplified_plan_name + subscription_age"

Let's build our first model.

``` r
# first model
logreg <- glm(formula = formula, data = training, family = binomial(link = "logit"))
```

Now let's summarize the model.

``` r
summary(logreg)
```

    ## 
    ## Call:
    ## glm(formula = formula, family = binomial(link = "logit"), data = training)
    ## 
    ## Deviance Residuals: 
    ##     Min       1Q   Median       3Q      Max  
    ## -1.2974  -0.5734  -0.4359  -0.3020   3.1194  
    ## 
    ## Coefficients:
    ##                                Estimate Std. Error z value Pr(>|z|)    
    ## (Intercept)                  -6.726e-01  4.096e-02 -16.422  < 2e-16 ***
    ## has_team_memberTRUE          -3.733e-01  6.185e-02  -6.035 1.59e-09 ***
    ## is_mobile_userTRUE           -5.091e-01  3.761e-02 -13.535  < 2e-16 ***
    ## number_of_profiles           -3.210e-04  1.072e-03  -0.299 0.764658    
    ## has_refunded_chargeTRUE       1.066e+00  8.546e-02  12.480  < 2e-16 ***
    ## has_failed_chargeTRUE        -2.516e-01  3.859e-02  -6.519 7.07e-11 ***
    ## update_past_four_daysTRUE    -1.811e-01  4.840e-02  -3.741 0.000183 ***
    ## estimate                     -2.132e-05  1.919e-05  -1.111 0.266586    
    ## weeks_with_updates1          -1.826e-01  6.479e-02  -2.818 0.004835 ** 
    ## weeks_with_updates2          -2.174e-01  7.101e-02  -3.061 0.002205 ** 
    ## weeks_with_updates3          -2.683e-01  7.448e-02  -3.603 0.000315 ***
    ## weeks_with_updates4          -3.122e-01  7.730e-02  -4.038 5.39e-05 ***
    ## weeks_with_updates5          -3.790e-01  7.695e-02  -4.925 8.42e-07 ***
    ## weeks_with_updates6          -6.621e-01  8.151e-02  -8.122 4.57e-16 ***
    ## weeks_with_updates7          -5.921e-01  7.351e-02  -8.054 8.01e-16 ***
    ## weeks_with_updates8          -8.462e-01  6.009e-02 -14.082  < 2e-16 ***
    ## total_updates                 6.451e-06  3.250e-06   1.985 0.047159 *  
    ## simplified_plan_namebusiness -2.424e-01  7.026e-02  -3.450 0.000560 ***
    ## subscription_age             -1.116e-03  5.300e-05 -21.052  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## (Dispersion parameter for binomial family taken to be 1)
    ## 
    ##     Null deviance: 24715  on 32563  degrees of freedom
    ## Residual deviance: 22932  on 32545  degrees of freedom
    ##   (556 observations deleted due to missingness)
    ## AIC: 22970
    ## 
    ## Number of Fisher Scoring iterations: 5

We have a lot of significant factors here. It looks like the number of profiles and total updates don't add much predictive power, so let's remove them. We might try scaling them first though or applying a log transformation.

``` r
# list features
features <- c('has_team_member', 'is_mobile_user', 'has_refunded_charge', 'log(total_updates + 1)',
              'has_failed_charge', 'update_past_four_days', 'weeks_with_updates', 'scale(estimate)',
              'simplified_plan_name', 'subscription_age')

# collapse list to string
feature_string <- paste(features, collapse = ' + ')

# model formula
formula2 <- paste0('did_churn ~ ', feature_string)

# second model
logreg2 <- glm(formula = formula2, data = training, family = binomial(link = "logit"))

# summarize model
summary(logreg2)
```

    ## 
    ## Call:
    ## glm(formula = formula2, family = binomial(link = "logit"), data = training)
    ## 
    ## Deviance Residuals: 
    ##     Min       1Q   Median       3Q      Max  
    ## -1.3017  -0.5743  -0.4387  -0.3037   3.1122  
    ## 
    ## Coefficients:
    ##                                Estimate Std. Error z value Pr(>|z|)    
    ## (Intercept)                  -6.859e-01  4.030e-02 -17.019  < 2e-16 ***
    ## has_team_memberTRUE          -3.733e-01  6.152e-02  -6.068 1.29e-09 ***
    ## is_mobile_userTRUE           -5.088e-01  3.748e-02 -13.576  < 2e-16 ***
    ## has_refunded_chargeTRUE       1.064e+00  8.406e-02  12.662  < 2e-16 ***
    ## log(total_updates + 1)       -3.021e-02  1.833e-02  -1.648 0.099280 .  
    ## has_failed_chargeTRUE        -2.473e-01  3.831e-02  -6.454 1.09e-10 ***
    ## update_past_four_daysTRUE    -1.632e-01  4.855e-02  -3.361 0.000777 ***
    ## weeks_with_updates1          -1.137e-01  7.450e-02  -1.526 0.127052    
    ## weeks_with_updates2          -1.211e-01  9.029e-02  -1.342 0.179710    
    ## weeks_with_updates3          -1.511e-01  9.854e-02  -1.533 0.125157    
    ## weeks_with_updates4          -1.834e-01  1.048e-01  -1.749 0.080292 .  
    ## weeks_with_updates5          -2.387e-01  1.071e-01  -2.229 0.025806 *  
    ## weeks_with_updates6          -5.265e-01  1.150e-01  -4.577 4.72e-06 ***
    ## weeks_with_updates7          -4.362e-01  1.138e-01  -3.831 0.000128 ***
    ## weeks_with_updates8          -6.634e-01  1.162e-01  -5.708 1.15e-08 ***
    ## scale(estimate)              -4.614e-02  2.143e-02  -2.153 0.031320 *  
    ## simplified_plan_namebusiness -2.189e-01  6.835e-02  -3.203 0.001360 ** 
    ## subscription_age             -1.120e-03  5.269e-05 -21.255  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## (Dispersion parameter for binomial family taken to be 1)
    ## 
    ##     Null deviance: 24962  on 32805  degrees of freedom
    ## Residual deviance: 23187  on 32788  degrees of freedom
    ##   (314 observations deleted due to missingness)
    ## AIC: 23223
    ## 
    ## Number of Fisher Scoring iterations: 5

Ok, let's remove total updates from our final model.

``` r
# list features
features <- c('has_team_member', 'is_mobile_user', 'has_refunded_charge', 
              'has_failed_charge', 'update_past_four_days', 'weeks_with_updates', 'scale(estimate)',
              'simplified_plan_name', 'subscription_age')

# collapse list to string
feature_string <- paste(features, collapse = ' + ')

# model formula
formula3 <- paste0('did_churn ~ ', feature_string)

# second model
logreg3 <- glm(formula = formula3, data = training, family = binomial(link = "logit"))

# summarize model
summary(logreg3)
```

    ## 
    ## Call:
    ## glm(formula = formula3, family = binomial(link = "logit"), data = training)
    ## 
    ## Deviance Residuals: 
    ##     Min       1Q   Median       3Q      Max  
    ## -1.2990  -0.5745  -0.4385  -0.3040   3.1130  
    ## 
    ## Coefficients:
    ##                                Estimate Std. Error z value Pr(>|z|)    
    ## (Intercept)                  -6.869e-01  4.029e-02 -17.048  < 2e-16 ***
    ## has_team_memberTRUE          -3.685e-01  6.139e-02  -6.003 1.94e-09 ***
    ## is_mobile_userTRUE           -5.074e-01  3.747e-02 -13.541  < 2e-16 ***
    ## has_refunded_chargeTRUE       1.059e+00  8.395e-02  12.612  < 2e-16 ***
    ## has_failed_chargeTRUE        -2.500e-01  3.827e-02  -6.533 6.45e-11 ***
    ## update_past_four_daysTRUE    -1.744e-01  4.811e-02  -3.624 0.000290 ***
    ## weeks_with_updates1          -1.755e-01  6.453e-02  -2.719 0.006540 ** 
    ## weeks_with_updates2          -2.138e-01  7.086e-02  -3.018 0.002546 ** 
    ## weeks_with_updates3          -2.584e-01  7.423e-02  -3.480 0.000501 ***
    ## weeks_with_updates4          -3.011e-01  7.694e-02  -3.914 9.09e-05 ***
    ## weeks_with_updates5          -3.627e-01  7.648e-02  -4.742 2.11e-06 ***
    ## weeks_with_updates6          -6.608e-01  8.139e-02  -8.119 4.69e-16 ***
    ## weeks_with_updates7          -5.802e-01  7.321e-02  -7.926 2.27e-15 ***
    ## weeks_with_updates8          -8.282e-01  5.964e-02 -13.887  < 2e-16 ***
    ## scale(estimate)              -4.294e-02  2.097e-02  -2.048 0.040602 *  
    ## simplified_plan_namebusiness -2.237e-01  6.823e-02  -3.280 0.001040 ** 
    ## subscription_age             -1.115e-03  5.258e-05 -21.213  < 2e-16 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1
    ## 
    ## (Dispersion parameter for binomial family taken to be 1)
    ## 
    ##     Null deviance: 24962  on 32805  degrees of freedom
    ## Residual deviance: 23189  on 32789  degrees of freedom
    ##   (314 observations deleted due to missingness)
    ## AIC: 23223
    ## 
    ## Number of Fisher Scoring iterations: 5

Time to make some predictions. The additional parameter `type = "response"` tells the `predict()` function to return the predicted probabilities y.

``` r
# make predictions
training$pred <- predict(logreg3, newdata = training, type = "response")
testing$pred <- predict(logreg3, newdata = testing, type = "response")
```

Let's plot the predictions for users that churned and users that didn't.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-32-1.png)

Now let's make the same plot for the testing set.

![](logistic_regression_files/figure-markdown_github-ascii_identifiers/unnamed-chunk-33-1.png)

This is good! In order to use the model as a classifier, we must pick a threshold; scores above the threshold will be classified as positive, those below as negative. Here we can choose something like 15% or 20%.

The higher we set the threshold, the more precise the classifier will be (we’ll iden- tify a set of situations with a much higher-than-average rate of at-risk births); but we’ll also miss a higher percentage of at-risk situations, as well.

Let's build a confusion matrix using 15% as the threshold.

``` r
# build confusion matrix
confuse <-  table(pred = testing$pred > 0.15, churned = testing$did_churn)
confuse
```

    ##        churned
    ## pred       0    1
    ##   FALSE 5094  434
    ##   TRUE  2140  539

Now we can calculate precision, recall, and enrichment. Precision is defined as the number of true positives divided by the number of true positives plus the number of false positives. False positives are cases the model incorrectly labels as positive that are actually negative, or in our example, individuals the model classifies as terrorists that are not. While recall expresses the ability to find all relevant instances in a dataset, precision expresses the proportion of the data points our model says was relevant actually were relevant.

``` r
# calculate precision
precision <- confuse[2,2] / sum(confuse[2,])
precision
```

    ## [1] 0.2011945

Seems like we have a lot of false positives, but that might be alright. Recall is the number of true positives divided by the number of true positives plus the number of false negatives.

``` r
# calculate recall
recall <- confuse[2,2] / sum(confuse[,2])
recall
```

    ## [1] 0.5539568

The ratio of the classifier precision to the average rate of positives is called the enrichment rate.

``` r
# calculate enrichment rate
enrich <- precision / mean(as.numeric(testing$did_churn))
enrich
```

    ## [1] 1.676958

Our logistic regression model identifies a set of potential at-risk subscriptions that finds about 55% of all the true at-risk subscriptions, with a true positive rate around 68% higher than the overall population rate.

### AUC

Let's calculate AUC to evaluate our model's performance.

``` r
# define what a positive result is
pos <- 1

# function to calculate AUC
calcAUC <- function(predcol, outcol) {
  
  perf <- performance(prediction(predcol, outcol == pos), 'auc') 
  as.numeric(perf@y.values)
  
}

# calculate AUC
calcAUC(testing[, "pred"], testing[, "did_churn"])
```

    ## [1] 0.6797732

Hey, that's not the worst result ever!
