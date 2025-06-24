import os
import time
import joblib
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import RobustScaler
from sklearn.feature_selection import SelectKBest, f_classif
import xgboost as xgb # type: ignore

# Directory for models
MODEL_DIR = 'models'
MODEL_PATH = os.path.join(MODEL_DIR, 'xgboost_latest.pkl')
os.makedirs(MODEL_DIR, exist_ok=True)

# Load dataset
df = pd.read_csv('SBH_Dataset.csv')

# Feature engineering
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

# Outlier removal
def remove_outliers(df, columns):
    for col in columns:
        Q1 = df[col].quantile(0.25)
        Q3 = df[col].quantile(0.75)
        IQR = Q3 - Q1
        df = df[(df[col] >= Q1 - 1.5 * IQR) & (df[col] <= Q3 + 1.5 * IQR)]
    return df

df = remove_outliers(df, ['Temp', 'SpO2', 'Heart_rate'])

# Handle missing values and duplicates
df = df.fillna(df.mean(numeric_only=True))
df = df.drop_duplicates()

# Features and labels
X = df.drop('Anomaly', axis=1)
y = df['Anomaly']

# Split data
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, stratify=y, random_state=42
)

# Feature selection
selector = SelectKBest(f_classif, k='all')
X_train = selector.fit_transform(X_train, y_train)
X_test = selector.transform(X_test)

# Scaling
scaler = RobustScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)
joblib.dump(scaler, os.path.join(MODEL_DIR, 'scaler.pkl'))

# Load or initialize model
if os.path.exists(MODEL_PATH):
    old_timestamp = int(time.time())
    os.rename(MODEL_PATH, os.path.join(MODEL_DIR, f'xgboost_{old_timestamp}_old.pkl'))
    print(f"Renamed existing model to xgboost_{old_timestamp}_old.pkl")

# Initialize and train model on GPU
xgb_model = xgb.XGBClassifier(
    n_estimators=300,
    max_depth=7,
    learning_rate=0.05,
    subsample=0.9,
    use_label_encoder=False,
    eval_metric='logloss',
    tree_method='gpu_hist',
    predictor='gpu_predictor',
    device='cuda',
    random_state=42
)

xgb_model.fit(X_train_scaled, y_train)

# Save latest model
joblib.dump(xgb_model, MODEL_PATH)
print("Model trained and saved to", MODEL_PATH)
