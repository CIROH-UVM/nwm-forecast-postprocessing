# -*- coding: utf-8 -*-
"""
Created on Thu Jun 19 13:38:10 2025

@author: mmorale3

Purpose: Test ML configuration on Notebook Test No.9 with different input features
for refinement and further evaluation.
This code should also work for any number of sites.
"""

from pathlib import Path
#import numpy as np
import os
import pandas as pd
import matplotlib.pyplot as plt
import lightgbm
from lightgbm import LGBMRegressor

from sklearn import set_config
from sklearn.metrics import mean_squared_error, root_mean_squared_error
from sklearn.pipeline import make_pipeline#, make_union
from sklearn.preprocessing import MinMaxScaler
from sklearn.pipeline import Pipeline
#from sklearn.base import clone
set_config(transform_output="pandas")  # Upgrade to scikit-learn 0.12
# for this feature

from feature_engine.imputation import DropMissingData
from feature_engine.datetime import DatetimeFeatures
from feature_engine.imputation import DropMissingData
from feature_engine.selection import DropFeatures
from feature_engine.encoding import OrdinalEncoder, OneHotEncoder

# Testing ID
#------------
testID = "wq_2_e"#"wq_e"#"1wq"
test_no = "wq_2_1b_e"#"wq_e"
#-------------------------
# Loading input dataset
#-------------------------
# Directory containing the raw data
base_dir = Path("/users/m/m/mmorale3/netfiles/ciroh/mmorales/NWM_forecasts/NWM_mlCorrection")
data_sources = Path(base_dir,"final_inputDb")

# Artifacts directory for storing the
# training data, models, pipelines etc.
artifacts_dir = Path(base_dir,"output")
#training_dir = artifacts_dir / "training" # Directory to store our features for training.
pipeline_dir = artifacts_dir / "pipeline" # Directory to store our feature engineering pipeline.
forecast_dir = artifacts_dir / "forecast"

# Create directories
for _dir in [artifacts_dir, pipeline_dir,forecast_dir]:
    _dir.mkdir(exist_ok=True)

# Reading input dataset which includes the static, lag and windows features and 
# future NWM already computed - Processed with R
ml_ds = data_sources / f'ml_input_db_{testID}.csv'
input_features = pd.read_csv(ml_ds, index_col=["reference_time"], dtype={'siteID': 'string'})
print(input_features.head())

# Cast datetime variable in datetime format.
input_features.index = pd.to_datetime(input_features.index,format='mixed')
input_features = input_features.sort_values(by=["siteID", "reference_time"]) # Sort to ensure the time series groups are contiguous.

# option to work with only one site
input_features = input_features[input_features['siteID'] == '01362500']

#-----------------------------------
# Reading parquet as an option
#input_features = pd.read_parquet(ml_ds)
#input_features.set_index('dateTime', inplace=True)
#input_features.head()

# To double check column names or features
print(list(input_features.columns.values))

#---------------------------------
# Select the siteID to work with
#---------------------------------
print(input_features['siteID'].unique())
# We won't filter any site out
df_ml = input_features.copy()

# Sanity check: data span.
print(df_ml.index.min(), df_ml.index.max())

# Count the number of missing values in each column using isnull().sum()
missings = df_ml.isnull().sum()
#print(missings)
print((missings/len(df_ml))*100)

# Temporarily, save the dataset for this site in a parquet file
#f_out = training_dir / "data.parquet"
#df_ml.to_parquet(f_out)

#----------------------------------
# DEFINE PIPELINE
#----------------------------------
# Drop features we don't want to consider
#------------------------------------------
drop_dict = {
    "1wq":      ["value_time"],
    "wq":       ["value_time"],
    "wq_1":     ["value_time","V2D_nwm_mr"],
    "wq_e":     ["value_time","V2D_nwm_mr"],
    "wq_2":     ["value_time","V2D_nwm_mr"],
    "wq_2_b":   ["value_time","V2D_nwm_mr","V2D_mean_roll8","V2D_mean_roll12",
                 "V2D_mean_roll24","V2D_mean_roll48"],
    "wq_2_e":   ["value_time","V2D_nwm_mr"],
    "wq_2_b_e": ["value_time","V2D_nwm_mr","V2D_mean_roll8","V2D_mean_roll12",
                 "V2D_mean_roll24","V2D_mean_roll48"],
    "wq_2_1_e": ["value_time","V2D_nwm_mr"],
    "wq_2_1b_e": ["value_time","V2D_nwm_mr","V2D_mean_roll8","V2D_mean_roll12",
                 "V2D_mean_roll24","V2D_mean_roll48"],
    "wq_2_1":   ["value_time","V2D_nwm_mr"]
    }   

to_drop = drop_dict[test_no]
print("Dropping the following features...")
print(to_drop)

df_ml = df_ml.drop(columns=to_drop)

# Remove NAs for target
df_ml.dropna(inplace=True)
df_ml.head()

# Categorical features
#----------------------
# Change the type of siteID to be able to change it with the categorical encoder
#df_ml["calib_tag"] = df_ml.calib_tag.astype("object")

# ordinal encoding
#o_enc = OrdinalEncoder(
#    encoding_method="arbitrary",  # assigns integers arbitrarily
#    variables=['calib_tag'] # Only for Test10_5
#)

# Fit is for the encoder to learn the categories
#o_enc.fit(df_ml)
#print(o_enc.variables_)
#print(o_enc.encoder_dict_)

# Apply encoding
#df_ml = o_enc.transform(df_ml)
#print(df_ml["calib_tag"].unique())

# One hot encoding (OHE)
ohe_enc = OneHotEncoder(
     variables=['nwmVersion'],
     drop_last=False,
     )

#ohe_enc.fit(df_ml)
#print(ohe_enc.variables_)
#print(ohe_enc.encoder_dict_)

# Periodic features
#----------------------
dtf = DatetimeFeatures(
    # the datetime variable
    variables="index",

    # the features we want to create
    features_to_extract=[
        #"year",
        "month",
        "day_of_month"#,
        #"hour" # Only for Test10_5
    ],
)

# Imputer for dropping missing data
#----------------------------------
# Drop missing data
imputer = DropMissingData(missing_only=False)

# Define pipeline
#-----------------
pipe = Pipeline(
    [("datetime_features", dtf),
     ("onehotencoder_features", ohe_enc),     
     #("drop_ts", drop_ts),
     ("dropna", imputer),])

# Rescale our features
pipeline = make_pipeline(pipe,MinMaxScaler())

# Let's save our pipeline to use in real time forecasts
#f_out = pipeline_dir / f"pipeline.joblib"
#joblib.dump(pipeline, f_out)

#------------------------------
# MODEL SETUP
#------------------------------
# Define model parameters
lgb_params = {
    "boosting_type": "gbdt",
    "linear_tree": True, 
    "linear_lambda": 0.1, 
    "n_estimators": 300,
    "importance_type": 'split',
    #"objective": "tweedie",
    #"tweedie_variance_power": 1.1,
    #"metric": "rmse",
    #"learning_rate": 0.3,
    #"n_estimators": 100,
    #"boost_from_average": True,
    #"verbose": -1,
    #"monotone_constraints": monotone_constraints,
    "n_jobs": 4, # If active, it causes different results each time
    "random_state": 42
}

model = LGBMRegressor(**lgb_params)

# Define our target value
#target = ["qobs_cms"]
target = ["q_error"]

# Sanity check
print(df_ml['siteID'].unique())
print(list(df_ml.columns.values))

# Define time of first forecast, this determines our train / test split
forecast_start_time = pd.to_datetime("2022-06-30 23:59:59")

# --- CREATE TRAINING & TESTING DATAFRAME  --- #
# Ensure we only have training data up to the start
# of the forecast.
df_train = df_ml.loc[df_ml.index < forecast_start_time].copy()
df_train = df_train.drop(columns=['siteID'])
df_train_bckup = df_ml.loc[df_ml.index < forecast_start_time].copy()

df_test = df_ml.loc[df_ml.index >= forecast_start_time].copy()
df_test = df_test.drop(columns=['siteID'])
df_test_bckup = df_ml.loc[df_ml.index >= forecast_start_time].copy()

# --- FEATURE ENGINEERING--- #
# Create X_train and y_train
#y_train = pipeline.fit_transform(df_train)[target]
y_train = df_train.dropna()[target]
#X_train = pipeline.fit_transform(df_train).drop(columns=["qobs_cms"])
# For the case of error prediction
X_train = pipeline.fit_transform(df_train).drop(columns=["qobs_cms","q_error"])

# --- MODEL TRAINING---#
model.fit(X_train, y_train)

#----- PREDICT USING ALL THE TESTING PERIOD----#
#X_test = pipeline.transform(df_test).drop(columns=["qobs_cms"])
# For the case of error prediction
X_test = pipeline.transform(df_test).drop(columns=["qobs_cms","q_error"])
# Predict one step ahead.
y_pred = model.predict(X_test)
    
# --- GET FORECAST AND TEST VALUES --- #
y_test = df_test.dropna()[target]

# Sanity checks
#print(df_train['nwmVersion'].unique())
#print(df_test['nwmVersion'].unique())
#print(df_train.index.min(), df_train.index.max())
#print(df_test.index.min(), df_test.index.max())

#print(list(X_test.columns.values))
#print(list(X_train.columns.values))

#---------------------------------------------------------
# Save the results to postprocess in R and assess results
#---------------------------------------------------------
#df_y_pred = df_test.dropna()[["qobs_cms","q_nwm_mr","lead_time"]]
# For the case of error prediction
df_y_pred = df_test.dropna()[["q_error","qobs_cms","q_nwm_mr","lead_time"]]
df_y_pred['y_pred'] = y_pred.tolist()
df_y_pred['siteID'] = df_test_bckup.dropna()['siteID'].tolist()
df_y_pred.to_csv(f'{artifacts_dir}/forecast/forecasts_{test_no}.csv')

# If q_nwm is dropped
# df_y_pred = df_test.dropna()[["qobs_cms","lead_time"]]
# df_y_pred['y_pred'] = y_pred.tolist()
# df_y_pred['siteID'] = df_test_bckup.dropna()['siteID'].tolist()
# df_y_pred.to_csv(f'{artifacts_dir}/forecast/forecasts_{test_no}.csv')

# See feature importance
#------------------------
ax = lightgbm.plot_importance(model)
figure = plt.gcf()
figure.set_size_inches(9, 18)
plt.savefig(f'{artifacts_dir}/forecast/FImportance_{test_no}.png',dpi=(100), bbox_inches='tight')



