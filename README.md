<p align="center">
    <img width=50% src="https://user-images.githubusercontent.com/1682202/41096236-415e3442-6a54-11e8-8dad-20d13c2fbe69.png">
</p>

<p align="center">
    <i>Churn forecasting at Buffer.</i>
</p>

<p align="center">
  <img width="460" height="300" src="https://media.giphy.com/media/3owyoRr3kZMz0uV2la/giphy.gif">
</p>

![license](https://img.shields.io/github/license/mashape/apistatus.svg)

## Introduction

Churn occurs when customers or subscribers stop doing business with a company or service. Predicting those events helps us to know more about our service and how customers benefit from it.

That said, there is no correct way to do churn prediction. This repository contains our approach to do churn prediction with Machine Learning!

## Defining the Problem
So what specifically are we trying to predict here? The answer to this question will determine the types of models we build and how we evaluate them. Initially at least, we will try to predict whether or not a customer will cancel his or her subscription within a given time period. This makes the it a binary classification problem (churn or not churn).

Once we feel confident in our binary classification model, we may move on to [more complex models](https://ragulpr.github.io/2016/12/22/WTTE-RNN-Hackless-churn-modeling/) that try to predict _the amount of time until a churn event_. In this case, we are no longer dealing with a classification model. It isn't a regression model either.

## The Measure of Success
Initially, with the binary classification model, we will use the area under the receiver operating characteristic curve (AUC) as the success metric. We could use model accuracy (# users classified correctly / # users) as the success metric, however imbalanced classes causes this metric measure of success to be insufficient -- we could assume that nobody churns and have an accuracy of over 90%.

 The _receiver operating characteristic curve_ (ROC) works like this. It plots sensitivity, the probability of predicting a real positive will be a positive, against 1-specificity, or the probability of predicting a false positive.This curve represents every possible trade-off between sensitivity and specificity that is available for this classifier.

 ![ROC](https://www.medcalc.org/manual/_help/images/roc_intro3.png)

 When the area under this curve is maximized, the false positive rate increases much more slowly than the true positive rate, meaning that we are accurately predicting positives (churn) without incorrectly labeling so many negatives (non churns).

## Model Evaluation
To evaluate our models, we will maintain a hold-out validation set that is not used to train the model. Notice that we will then have three separate datasets: a training set, a testing set, and a validation set.

The reason that we need the hold-out validation set is that information from the testing set "leaks" into the model each time we use the testing set to score our model's performance during training.

## Determining a Baseline
Our predictive models must beat the performance of two models:

 - A "dumb" model that uses the average churn rate to randomly assign users a value of "churned" or "not churned".
 - A simple logistic regression model.

 Remember that these models must be out-performed on the hold-out validation set.

## Defining Inputs and Outputs
We define a customer as churned if they cancel their subscription. Our inputs will consist of snapshot data (billing info) and time series data (detailed usage info). We will use 8 weeks of snapshot and time series data to build our feature sets. We will try to predict whether or not a customer will churn _in the next 4 weeks_.
