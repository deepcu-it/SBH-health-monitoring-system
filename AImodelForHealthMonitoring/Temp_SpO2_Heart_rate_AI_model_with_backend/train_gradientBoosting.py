# train_gradient_boosting.py
import os
import time
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import RobustScaler
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.ensemble import GradientBoostingClassifier
 
# Create models directory
os.makedirs('models', exist_ok=True)
model_path = 'models/gb_latest.pkl'
 
old_model_exists = False
 
# Check for existing model
if os.path.exists(model_path):
    old_timestamp = int(time.time())
    old_model_path = f'models/gb_{old_timestamp}_old.pkl'
    os.rename(model_path, old_model_path)
    gb_model = joblib.load(old_model_path)
    print(f"Loaded existing model and renamed to {old_model_path}")
    old_model_exists = True
else:
    gb_model = GradientBoostingClassifier(
        n_estimators=300,
        max_depth=5,
        learning_rate=0.05,
        subsample=0.9,
        random_state=42
    )
    print("Created new GradientBoosting model.")
 
# Load dataset
if old_model_exists :
  df = pd.read_csv('SBH_Dataset_new.csv')
else :
  df = pd.read_csv('SBH_Dataset.csv')
 
# Feature Engineering
df['temp_spo2_ratio'] = df['Temp'] / (df['SpO2'] + 1e-6)
df['heart_rate_temp_ratio'] = df['Heart_rate'] / (df['Temp'] + 1e-6)
df['spo2_heart_rate_ratio'] = df['SpO2'] / (df['Heart_rate'] + 1e-6)
df['temp_squared'] = df['Temp'] ** 2
df['spo2_squared'] = df['SpO2'] ** 2
df['heart_rate_squared'] = df['Heart_rate'] ** 2
window_size = 5
df['temp_rolling_mean'] = df['Temp'].rolling(window=window_size, min_periods=1).mean()
df['spo2_rolling_mean'] = df['SpO2'].rolling(window=window_size, min_periods=1).mean()
df['heart_rate_rolling_mean'] = df['Heart_rate'].rolling(window=window_size, min_periods=1).mean()
 
# Remove outliers
def remove_outliers(df, columns):
    for col in columns:
        Q1 = df[col].quantile(0.25)
        Q3 = df[col].quantile(0.75)
        IQR = Q3 - Q1
        lower = Q1 - 1.5 * IQR
        upper = Q3 + 1.5 * IQR
        df = df[(df[col] >= lower) & (df[col] <= upper)]
    return df
 
df = remove_outliers(df, ['Temp', 'SpO2', 'Heart_rate'])
 
# Preprocess
df.fillna(df.mean(), inplace=True)
df.drop_duplicates(inplace=True)
 
# Split data
X = df.drop('Anomaly', axis=1)
y = df['Anomaly']
X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)
 
# Feature selection
selector = SelectKBest(score_func=f_classif, k='all')
X_train = selector.fit_transform(X_train, y_train)
X_test = selector.transform(X_test)
 
# Scale features
scaler = RobustScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)
joblib.dump(scaler, 'models/gb_scaler.pkl')
 
# Train model
gb_model.fit(X_train_scaled, y_train)
 
# Save new model
joblib.dump(gb_model, model_path)
print("Trained and saved model to models/gb_latest.pkl")