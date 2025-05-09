from flask import Flask, request, jsonify
import joblib
import pandas as pd
import numpy as np

app = Flask(__name__)

# Load the trained model
model = joblib.load('best_model.joblib')

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Get data from request
        data = request.get_json()
        
        # Convert to DataFrame
        input_data = pd.DataFrame([{
            'Temp': float(data['temp']),
            'SpO2': float(data['spo2']),
            'SYS': float(data['sys']),
            'DIA': float(data['dia']),
            'Heart_rate': float(data['heart_rate'])
        }])
        
        # Make prediction
        prediction = model.predict(input_data)[0]
        probability = model.predict_proba(input_data)[0][1]
        
        # Prepare response
        response = {
            'anomaly': bool(prediction),
            'probability': float(probability),
            'message': 'Anomaly detected' if prediction else 'No anomaly detected'
        }
        
        return jsonify(response)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 