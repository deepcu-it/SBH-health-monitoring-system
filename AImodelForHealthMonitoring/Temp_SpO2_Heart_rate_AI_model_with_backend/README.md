# Anomaly Detection Project

This project implements a complete machine learning pipeline for anomaly detection, including model training, evaluation, and a Flask API for serving predictions.

## Project Structure

```
SBH_AnomalyProject/
│
├── SBH_Dataset.csv
├── app.py  # Flask backend
├── model_training.py  # Contains all ML logic
├── models/
│   └── best_model.pkl
├── charts/
│   ├── correlation_heatmap.png
│   ├── feature_importance_rf.png
│   └── ...
├── model_comparison.csv
├── requirements.txt
└── README.md
```

## Setup

1. Create a virtual environment (recommended):
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Training the Models

To train all models and generate evaluation metrics:

```bash
python model_training.py
```

This will:
- Perform exploratory data analysis
- Generate visualizations in the `charts/` directory
- Train multiple models
- Save evaluation metrics to `model_comparison.csv`
- Save the best model to `models/best_model.pkl`

### Running the API

To start the Flask API:

```bash
python app.py
```

The API will be available at `http://localhost:5000`

### Making Predictions

Send a POST request to `/predict` with your input features in JSON format:

```bash
curl -X POST http://localhost:5000/predict \
     -H "Content-Type: application/json" \
     -d '{"feature1": value1, "feature2": value2, ...}'
```

The API will return:
```json
{
    "anomaly_probability": 0.87,
    "is_anomaly": true
}
```

## Model Evaluation

The `model_comparison.csv` file contains detailed metrics for all trained models:
- Training accuracy
- Test accuracy
- Precision
- Recall
- F1-score
- ROC-AUC score

## Visualizations

The `charts/` directory contains:
- Correlation heatmap
- Feature importance plots
- Distribution plots
- Confusion matrices for each model 