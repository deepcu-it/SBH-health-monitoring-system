class HealthData {
  final DateTime timestamp;
  final double heartRate;
  final double spo2;
  final double temperature;
  final bool hasAnomaly;

  HealthData({
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    this.hasAnomaly = false,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'heartRate': heartRate,
        'spo2': spo2,
        'temperature': temperature,
        'hasAnomaly': hasAnomaly,
      };

  factory HealthData.fromJson(Map<String, dynamic> json) => HealthData(
        timestamp: DateTime.parse(json['timestamp']),
        heartRate: json['heartRate'].toDouble(),
        spo2: json['spo2'].toDouble(),
        temperature: json['temperature'].toDouble(),
        hasAnomaly: json['hasAnomaly'] ?? false,
      );
}
