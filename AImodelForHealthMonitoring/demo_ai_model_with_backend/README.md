# Health Monitoring Anomaly Detection System

This project implements a machine learning-based anomaly detection system for health monitoring data. It uses various machine learning models to detect anomalies in health parameters and provides a REST API for real-time predictions.

## Features

- Multiple ML model comparison (Random Forest, XGBoost, LightGBM, CatBoost)
- Comprehensive model evaluation and visualization
- REST API for real-time anomaly detection
- Feature importance analysis
- Confusion matrix visualization

## Installation

1. Clone the repository
2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

1. Train the models:
```bash
python model_training.py
```
This will:
- Train multiple models
- Generate performance metrics
- Save the best model
- Create visualization plots

2. Start the API server:
```bash
python app.py
```

3. Make predictions using the API:
```bash
curl -X POST http://localhost:5000/predict \
-H "Content-Type: application/json" \
-d '{
    "age": 45,
    "gender": "Male",
    "heart_rate": 85,
    "spo2": 97,
    "blood_pressure_systolic": 120,
    "blood_pressure_diastolic": 80,
    "body_temperature": 36.6
}'
```

## API Endpoints

- `POST /predict`: Make anomaly predictions
- `GET /health`: Check API health status

## Model Input Format

The API expects JSON data with the following fields:
- age (integer)
- gender (string: "Male" or "Female")
- heart_rate (integer)
- spo2 (integer)
- blood_pressure_systolic (integer)
- blood_pressure_diastolic (integer)
- body_temperature (float)

## Output Format

The API returns JSON with:
- anomaly (boolean): Whether an anomaly was detected
- probability (float): Probability of anomaly
- message (string): Description of the prediction 