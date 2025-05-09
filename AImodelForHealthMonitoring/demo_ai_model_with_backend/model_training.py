# type: ignore
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score, accuracy_score, precision_score, recall_score, f1_score
import matplotlib.pyplot as plt
import seaborn as sns 
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier, AdaBoostClassifier, ExtraTreesClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.naive_bayes import GaussianNB
from xgboost import XGBClassifier
from lightgbm import LGBMClassifier
from catboost import CatBoostClassifier
from sklearn.cluster import KMeans
import joblib
import json

# Load the dataset
df = pd.read_csv('Dataset.csv')

# Convert boolean anomaly to numeric
df['Anomaly'] = df['Anomaly'].astype(int)

# Separate features and target
X = df.drop('Anomaly', axis=1)
y = df['Anomaly']

# Split the data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# Define preprocessing steps
preprocessor = StandardScaler()

# Define models to try
models = {
    'Random Forest': RandomForestClassifier(random_state=42),
    'XGBoost': XGBClassifier(random_state=42),
    'LightGBM': LGBMClassifier(random_state=42),
    'CatBoost': CatBoostClassifier(random_state=42, verbose=False),
    'Logistic Regression': LogisticRegression(random_state=42),
    'SVM': SVC(random_state=42, probability=True),
    'KNN': KNeighborsClassifier(),
    'Gradient Boosting': GradientBoostingClassifier(random_state=42),
    'AdaBoost': AdaBoostClassifier(random_state=42),
    'Extra Trees': ExtraTreesClassifier(random_state=42),
    'Naive Bayes': GaussianNB()
}

# Train and evaluate models
results = {}
best_model = None
best_score = 0

for name, model in models.items():
    # Create pipeline
    pipeline = Pipeline(steps=[
        ('preprocessor', preprocessor),
        ('classifier', model)
    ])
    
    # Train model
    pipeline.fit(X_train, y_train)
    
    # Make predictions
    y_pred = pipeline.predict(X_test)
    y_pred_proba = pipeline.predict_proba(X_test)[:, 1]
    
    # Calculate metrics
    train_score = pipeline.score(X_train, y_train)
    test_score = pipeline.score(X_test, y_test)
    roc_auc = roc_auc_score(y_test, y_pred_proba)
    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    
    # Cross-validation
    cv_scores = cross_val_score(pipeline, X, y, cv=5, scoring='roc_auc')
    
    # Store results without the pipeline object
    results[name] = {
        'train_accuracy': float(train_score),
        'test_accuracy': float(test_score),
        'roc_auc': float(roc_auc),
        'precision': float(precision),
        'recall': float(recall),
        'f1_score': float(f1),
        'cv_mean': float(cv_scores.mean()),
        'cv_std': float(cv_scores.std()),
        'classification_report': classification_report(y_test, y_pred, output_dict=True),
        'confusion_matrix': confusion_matrix(y_test, y_pred).tolist()
    }
    
    # Update best model
    if roc_auc > best_score:
        best_score = roc_auc
        best_model = pipeline

# Save the best model
joblib.dump(best_model, 'best_model.joblib')

# Save detailed results to JSON
with open('model_evaluation.json', 'w') as f:
    json.dump(results, f, indent=4)

# Generate visualizations
# 1. Model Comparison
metrics = ['train_accuracy', 'test_accuracy', 'roc_auc', 'precision', 'recall', 'f1_score']
plt.figure(figsize=(20, 10))
for i, metric in enumerate(metrics, 1):
    plt.subplot(2, 3, i)
    values = [results[model][metric] for model in results]
    plt.bar(results.keys(), values)
    plt.title(metric.replace('_', ' ').title())
    plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('model_comparison.png')
plt.close()

# 2. Feature Importance for best model
if isinstance(best_model.named_steps['classifier'], (RandomForestClassifier, XGBClassifier, LGBMClassifier, GradientBoostingClassifier, ExtraTreesClassifier)):
    feature_names = X.columns
    
    if isinstance(best_model.named_steps['classifier'], RandomForestClassifier):
        importances = best_model.named_steps['classifier'].feature_importances_
    elif isinstance(best_model.named_steps['classifier'], XGBClassifier):
        importances = best_model.named_steps['classifier'].feature_importances_
    elif isinstance(best_model.named_steps['classifier'], LGBMClassifier):
        importances = best_model.named_steps['classifier'].feature_importances_
    elif isinstance(best_model.named_steps['classifier'], GradientBoostingClassifier):
        importances = best_model.named_steps['classifier'].feature_importances_
    else:
        importances = best_model.named_steps['classifier'].feature_importances_
    
    plt.figure(figsize=(10, 6))
    sns.barplot(x=importances, y=feature_names)
    plt.title('Feature Importance')
    plt.tight_layout()
    plt.savefig('feature_importance.png')
    plt.close()

# 3. Clustering Visualization
# Apply KMeans clustering
kmeans = KMeans(n_clusters=2, random_state=42)
X_scaled = preprocessor.fit_transform(X)
clusters = kmeans.fit_predict(X_scaled)

# Create a 2D visualization using PCA
from sklearn.decomposition import PCA
pca = PCA(n_components=2)
X_pca = pca.fit_transform(X_scaled)

plt.figure(figsize=(10, 6))
scatter = plt.scatter(X_pca[:, 0], X_pca[:, 1], c=clusters, cmap='viridis', alpha=0.6)
plt.colorbar(scatter)
plt.title('Clustering Visualization of Anomalies')
plt.xlabel('Principal Component 1')
plt.ylabel('Principal Component 2')
plt.savefig('clustering_visualization.png')
plt.close()

# Print summary
print("\nModel Performance Summary:")
for name, result in results.items():
    print(f"\n{name}:")
    print(f"Training Accuracy: {result['train_accuracy']:.4f}")
    print(f"Testing Accuracy: {result['test_accuracy']:.4f}")
    print(f"ROC AUC Score: {result['roc_auc']:.4f}")
    print(f"Precision: {result['precision']:.4f}")
    print(f"Recall: {result['recall']:.4f}")
    print(f"F1 Score: {result['f1_score']:.4f}")
    print(f"Cross-validation Mean: {result['cv_mean']:.4f} ± {result['cv_std']:.4f}")

# Print best model
best_model_name = [name for name, result in results.items() if result['roc_auc'] == best_score][0]
print(f"\nBest Model: {best_model_name}")
print(f"Best ROC AUC Score: {best_score:.4f}") 