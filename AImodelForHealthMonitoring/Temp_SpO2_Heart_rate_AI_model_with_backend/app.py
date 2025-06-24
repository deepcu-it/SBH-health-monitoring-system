from flask import Flask, json, request, jsonify
import joblib
import numpy as np
import pandas as pd
import requests

app = Flask(__name__)

# Load the model and scaler
model = joblib.load('models/best_model.pkl')
scaler = joblib.load('models/scaler.pkl')

def engineer_features(df):
    """Apply the same feature engineering steps as in training"""
    # Create interaction features
    df['temp_spo2_ratio'] = df['Temp'] / (df['SpO2'] + 1e-6)
    df['heart_rate_temp_ratio'] = df['Heart_rate'] / (df['Temp'] + 1e-6)
    df['spo2_heart_rate_ratio'] = df['SpO2'] / (df['Heart_rate'] + 1e-6)

    # Create polynomial features
    df['temp_squared'] = df['Temp'] ** 2
    df['spo2_squared'] = df['SpO2'] ** 2
    df['heart_rate_squared'] = df['Heart_rate'] ** 2

    # Create rolling statistics (for single prediction, we'll use the current values)
    df['temp_rolling_mean'] = df['Temp']
    df['spo2_rolling_mean'] = df['SpO2']
    df['heart_rate_rolling_mean'] = df['Heart_rate']

    return df

#add the data format coming from the frontend
# {
#     "temperature": float,
#     "spo2": float,
#     "heart_rate": float
# }

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Get the input data
        data = request.get_json()
        
        # Validate input data
        required_fields = ['temperature', 'spo2', 'heart_rate']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
            if not isinstance(data[field], (int, float)):
                return jsonify({'error': f'Field {field} must be a number'}), 400
        
        # Convert input data to DataFrame with correct column names
        input_df = pd.DataFrame([{
            'Temp': data['temperature'],
            'SpO2': data['spo2'],
            'Heart_rate': data['heart_rate']
        }])
        
        # Apply feature engineering
        input_df = engineer_features(input_df)
        
        # Scale the input data
        input_scaled = scaler.transform(input_df)
        
        # Make prediction
        prediction_proba = model.predict_proba(input_scaled)[0][1]
        prediction = model.predict(input_scaled)[0]
        
        # Prepare response
        response = {
            'anomaly_probability': float(prediction_proba),
            'is_anomaly': bool(prediction),
            'input_data': {
                'temperature': float(data['temperature']),
                'spo2': float(data['spo2']),
                'heart_rate': float(data['heart_rate'])
            }
        }
        
        return jsonify(response)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 400
    

@app.route('/get-data-from-thinkspeak', methods=['GET'])
def get_data_from_thinkspeak():
    # ThingSpeak details
    channel_id = "2940434"
    api_key = "QTBTHPGUDEU25GZ1"
    url = f"https://api.thingspeak.com/channels/{channel_id}/feeds.json?api_key={api_key}&results=8000"

    try:
        # Request data from ThingSpeak
        response = requests.get(url)
        response.raise_for_status()

        data = response.json()
        feeds = data.get("feeds", [])

        # Create DataFrame with proper column names
        df = pd.DataFrame(feeds)
        df = df[["created_at", "field1", "field2", "field3"]]
        df.rename(columns={
            "field1": "Temperature",
            "field2": "Heart_Rate",
            "field3": "SpO2"
        }, inplace=True)

        # Save to CSV
        csv_filename = "thinkspeak_data.csv"
        df.to_csv(csv_filename, index=False)

        return jsonify({
            "message": f"Data successfully saved to {csv_filename}",
            "total_entries": len(df)
        }), 200

    except requests.exceptions.RequestException as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000) 