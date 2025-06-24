# type: ignore
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split, GridSearchCV, cross_val_score
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score, confusion_matrix, classification_report
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, ExtraTreesClassifier, VotingClassifier
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import Pipeline
from sklearn.feature_selection import SelectKBest, f_classif
import lightgbm as lgb
import joblib
import os

# Create necessary directories
os.makedirs('charts', exist_ok=True)
os.makedirs('models', exist_ok=True)

# Load the dataset
print("Loading dataset...")
df = pd.read_csv('SBH_Dataset.csv')

# EDA
print("\nPerforming Exploratory Data Analysis...")

# Check for missing values
missing_values = df.isnull().sum()
print("\nMissing Values:")
print(missing_values)

# Basic statistics
print("\nBasic Statistics:")
print(df.describe())

# Feature Engineering
print("\nPerforming Feature Engineering...")

# Create interaction features
df['temp_spo2_ratio'] = df['Temp'] / (df['SpO2'] + 1e-6)  # Avoid division by zero
df['heart_rate_temp_ratio'] = df['Heart_rate'] / (df['Temp'] + 1e-6)
df['spo2_heart_rate_ratio'] = df['SpO2'] / (df['Heart_rate'] + 1e-6)

# Create polynomial features for important columns
df['temp_squared'] = df['Temp'] ** 2
df['spo2_squared'] = df['SpO2'] ** 2
df['heart_rate_squared'] = df['Heart_rate'] ** 2

# Create rolling statistics
window_size = 5
df['temp_rolling_mean'] = df['Temp'].rolling(window=window_size, min_periods=1).mean()
df['spo2_rolling_mean'] = df['SpO2'].rolling(window=window_size, min_periods=1).mean()
df['heart_rate_rolling_mean'] = df['Heart_rate'].rolling(window=window_size, min_periods=1).mean()

# Handle outliers using IQR method
def remove_outliers(df, columns):
    df_clean = df.copy()
    for col in columns:
        Q1 = df_clean[col].quantile(0.25)
        Q3 = df_clean[col].quantile(0.75)
        IQR = Q3 - Q1
        lower_bound = Q1 - 1.5 * IQR
        upper_bound = Q3 + 1.5 * IQR
        df_clean = df_clean[(df_clean[col] >= lower_bound) & (df_clean[col] <= upper_bound)]
    return df_clean

# Remove outliers from numerical columns
numeric_columns = ['Temp', 'SpO2', 'Heart_rate']
df = remove_outliers(df, numeric_columns)

# Save correlation heatmap
plt.figure(figsize=(15, 10))
correlation_matrix = df.corr()
sns.heatmap(correlation_matrix, annot=True, cmap='coolwarm', fmt='.2f')
plt.title('Correlation Heatmap')
plt.tight_layout()
plt.savefig('charts/correlation_heatmap.png')
plt.close()

# Distribution plots for important features
numeric_columns = df.select_dtypes(include=[np.number]).columns
for col in numeric_columns[:5]:  # Plot first 5 numeric columns
    plt.figure(figsize=(10, 6))
    sns.histplot(data=df, x=col, kde=True)
    plt.title(f'Distribution of {col}')
    plt.savefig(f'charts/distribution_{col}.png')
    plt.close()

# Data Preprocessing
print("\nPreprocessing data...")

# Handle missing values if any
df = df.fillna(df.mean())

# Remove duplicates if any
df = df.drop_duplicates()

# Separate features and target
X = df.drop('Anomaly', axis=1)
y = df['Anomaly']

# Split the data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# Feature Selection
selector = SelectKBest(f_classif, k='all')
selector.fit(X_train, y_train)
feature_scores = pd.DataFrame({
    'Feature': X_train.columns,
    'Score': selector.scores_
})
feature_scores = feature_scores.sort_values('Score', ascending=False)
print("\nFeature Importance Scores:")
print(feature_scores)

# Scale the features using RobustScaler (more robust to outliers)
scaler = RobustScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Save the scaler
joblib.dump(scaler, 'models/scaler.pkl')

# Define hyperparameter grids for tuning
param_grids = {
    'Random Forest': {
        'n_estimators': [200, 300, 400],
        'max_depth': [15, 20, 25],
        'min_samples_split': [2, 5],
        'min_samples_leaf': [1, 2],
        'max_features': ['sqrt', 'log2']
    },
    'LightGBM': {
        'n_estimators': [200, 300, 400],
        'max_depth': [5, 7, 9],
        'learning_rate': [0.01, 0.05, 0.1],
        'num_leaves': [31, 63, 127],
        'subsample': [0.8, 0.9, 1.0]
    },
    'Gradient Boosting': {
        'n_estimators': [200, 300, 400],
        'max_depth': [5, 7, 9],
        'learning_rate': [0.01, 0.05, 0.1],
        'subsample': [0.8, 0.9, 1.0]
    },
    'SVM': {
        'C': [1, 10, 100],
        'gamma': ['scale', 'auto', 0.1, 0.01],
        'kernel': ['rbf', 'poly']
    }
}

# Initialize models with hyperparameter tuning
models = {
    'Random Forest': GridSearchCV(
        RandomForestClassifier(random_state=42),
        param_grids['Random Forest'],
        cv=5,
        scoring='roc_auc',
        n_jobs=-1
    ),
    'LightGBM': GridSearchCV(
        lgb.LGBMClassifier(random_state=42),
        param_grids['LightGBM'],
        cv=5,
        scoring='roc_auc',
        n_jobs=-1
    ),
    'Gradient Boosting': GridSearchCV(
        GradientBoostingClassifier(random_state=42),
        param_grids['Gradient Boosting'],
        cv=5,
        scoring='roc_auc',
        n_jobs=-1
    ),
    'SVM': GridSearchCV(
        SVC(probability=True, random_state=42),
        param_grids['SVM'],
        cv=5,
        scoring='roc_auc',
        n_jobs=-1
    ),
    'Logistic Regression': LogisticRegression(
        C=1.0,
        max_iter=1000,
        random_state=42
    ),
    'KNN': KNeighborsClassifier(
        n_neighbors=5,
        weights='distance',
        metric='minkowski'
    ),
    'Naive Bayes': GaussianNB()
}

# Train and evaluate models
results = []

for name, model in models.items():
    print(f"\nTraining {name}...")
    
    if isinstance(model, GridSearchCV):
        model.fit(X_train_scaled, y_train)
        best_model = model.best_estimator_
        print(f"Best parameters: {model.best_params_}")
    else:
        best_model = model
        best_model.fit(X_train_scaled, y_train)
    
    # Make predictions
    y_pred = best_model.predict(X_test_scaled)
    y_pred_proba = best_model.predict_proba(X_test_scaled)[:, 1]
    
    # Calculate metrics
    metrics = {
        'Model': name,
        'Train Accuracy': accuracy_score(y_train, best_model.predict(X_train_scaled)),
        'Test Accuracy': accuracy_score(y_test, y_pred),
        'Precision': precision_score(y_test, y_pred),
        'Recall': recall_score(y_test, y_pred),
        'F1 Score': f1_score(y_test, y_pred),
        'ROC AUC': roc_auc_score(y_test, y_pred_proba)
    }
    results.append(metrics)
    
    # Save confusion matrix
    plt.figure(figsize=(8, 6))
    cm = confusion_matrix(y_test, y_pred)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
    plt.title(f'Confusion Matrix - {name}')
    plt.ylabel('True Label')
    plt.xlabel('Predicted Label')
    plt.savefig(f'charts/confusion_matrix_{name}.png')
    plt.close()
    
    # Plot feature importance for tree-based models
    if hasattr(best_model, 'feature_importances_'):
        plt.figure(figsize=(12, 6))
        importances = best_model.feature_importances_
        indices = np.argsort(importances)[::-1]
        plt.title(f'Feature Importance - {name}')
        plt.bar(range(X.shape[1]), importances[indices])
        plt.xticks(range(X.shape[1]), X.columns[indices], rotation=45, ha='right')
        plt.tight_layout()
        plt.savefig(f'charts/feature_importance_{name}.png')
        plt.close()

# Create an ensemble of the best models
best_models = []
for name, model in models.items():
    if isinstance(model, GridSearchCV):
        best_models.append((name, model.best_estimator_))
    else:
        best_models.append((name, model))

ensemble = VotingClassifier(
    estimators=best_models,
    voting='soft',
    n_jobs=-1
)

# Train ensemble
print("\nTraining Ensemble Model...")
ensemble.fit(X_train_scaled, y_train)

# Evaluate ensemble
y_pred_ensemble = ensemble.predict(X_test_scaled)
y_pred_proba_ensemble = ensemble.predict_proba(X_test_scaled)[:, 1]

ensemble_metrics = {
    'Model': 'Ensemble',
    'Train Accuracy': accuracy_score(y_train, ensemble.predict(X_train_scaled)),
    'Test Accuracy': accuracy_score(y_test, y_pred_ensemble),
    'Precision': precision_score(y_test, y_pred_ensemble),
    'Recall': recall_score(y_test, y_pred_ensemble),
    'F1 Score': f1_score(y_test, y_pred_ensemble),
    'ROC AUC': roc_auc_score(y_test, y_pred_proba_ensemble)
}
results.append(ensemble_metrics)

# Save results to CSV
results_df = pd.DataFrame(results)
results_df.to_csv('model_comparison.csv', index=False)

# Find best model based on ROC AUC
best_model_name = results_df.loc[results_df['ROC AUC'].idxmax(), 'Model']
if best_model_name == 'Ensemble':
    best_model = ensemble
else:
    best_model = models[best_model_name].best_estimator_ if isinstance(models[best_model_name], GridSearchCV) else models[best_model_name]

# Save best model
joblib.dump(best_model, 'models/best_model.pkl')

print(f"\nBest model: {best_model_name}")
print("\nModel comparison saved to model_comparison.csv")
print("Best model saved to models/best_model.pkl") 