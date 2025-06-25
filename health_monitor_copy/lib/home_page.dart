import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'health_card.dart';
import 'hospitals_page.dart';
import 'history_page.dart';
import 'models/health_data.dart';
import 'services/firebase_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final Logger _logger = Logger('HealthMonitor');
  final FirebaseService _firebaseService = FirebaseService();
  bool isLoading = false;
  bool hasAnomaly = false;
  bool hasError = false;
  String statusMessage = '';
  Timer? _refreshTimer;
  List<HealthData> healthHistory = [];
  Map<String, dynamic> healthData = {
    'heart_rate': 0,
    'spo2': 0,
    'temperature': 37.5,
  };

  final String thingSpeakApiKey = 'QTBTHPGUDEU25GZ1';
  final int channelId = 2940434;

  String get _aiModelBaseUrl {
    if (Platform.isAndroid) {
      return 'http://127.0.0.1:5000';
    } else if (Platform.isIOS) {
      return 'http://localhost:5000';
    } else {
      return 'http://localhost:5000';
    }
  }

  @override
  void initState() {
    super.initState();
    _setupLogging();
    _fetchData();
    _startRefreshTimer();
    _listenToAnomaly();
  }

  void _setupLogging() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
      if (record.error != null) {
        debugPrint('Error: ${record.error}');
      }
      if (record.stackTrace != null) {
        debugPrint('Stack trace: ${record.stackTrace}');
      }
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      _fetchData();
    });
  }

  void _listenToAnomaly() {
    _firebaseService.anomalyStream.listen((isAnomaly) {
      setState(() {
        hasAnomaly = isAnomaly;
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      hasAnomaly = false;
      hasError = false;
      statusMessage = 'Fetching data...';
    });

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _logger.info(
          'Fetching data from ThingSpeak... (Attempt ${retryCount + 1})',
        );
        final response = await http
            .get(
          Uri.parse(
            'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$thingSpeakApiKey&results=1',
          ),
        )
            .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Connection to ThingSpeak timed out');
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['feeds'] != null && data['feeds'].isNotEmpty) {
            final feed = data['feeds'][0];
            _logger.info('Data received from ThingSpeak: $feed');

            final newHealthData = {
              'temperature':
                  double.tryParse(feed['field1']?.toString() ?? '37.5') ?? 37.5,
              'heart_rate': double.tryParse(feed['field2']?.toString() ?? '0') ?? 0,
              'spo2':
                  double.tryParse(feed['field3']?.toString() ?? '0') ?? 0,
            };

            setState(() {
              healthData = newHealthData;
              statusMessage = 'Data fetched successfully';
            });

            // Add to history
            healthHistory.insert(
                0,
                HealthData(
                  timestamp: DateTime.now(),
                  heartRate: newHealthData['heart_rate'] as double,
                  spo2: newHealthData['spo2'] as double,
                  temperature: newHealthData['temperature'] as double,
                  hasAnomaly: hasAnomaly,
                ));
            // Keep only last 100 records
            if (healthHistory.length > 100) {
              healthHistory.removeRange(100, healthHistory.length);
            }

            if (healthData['heart_rate'] > 0 || healthData['spo2'] > 0) {
              await _checkForAnomalies(healthData);
            } else {
              setState(() {
                hasError = true;
                statusMessage = 'Invalid data received from ThingSpeak';
              });
            }
            break;
          } else {
            _logger.warning('No data available from ThingSpeak');
            setState(() {
              hasError = true;
              statusMessage = 'No data available from ThingSpeak';
            });
            break;
          }
        } else {
          _logger.severe('Error fetching data: ${response.statusCode}');
          setState(() {
            hasError = true;
            statusMessage = 'Error fetching data: ${response.statusCode}';
          });
          break;
        }
      } catch (e, stackTrace) {
        _logger.severe('Error connecting to ThingSpeak', e, stackTrace);
        setState(() {
          hasError = true;
          statusMessage = 'Error connecting to ThingSpeak: ${e.toString()}';
        });
        break;
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _checkForAnomalies(Map<String, dynamic> data) async {
    try {
      // Validate data before sending
      if (data['heart_rate'] <= 0 || data['spo2'] <= 0) {
        _logger.warning('Invalid data for anomaly check: $data');
        setState(() {
          hasError = true;
          statusMessage = 'Invalid health data for anomaly detection';
        });
        return;
      }

      final requestData = {
        'heart_rate': data['heart_rate'],
        'spo2': data['spo2'],
        'temperature': 37.5, // Default temperature value
      };

      _logger.info('Sending data to AI model: $requestData');
      _logger.info('Connecting to AI model at: $_aiModelBaseUrl/predict');

      final response = await http
          .post(
        Uri.parse('$_aiModelBaseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection to AI model timed out');
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> result = jsonDecode(response.body);
        _logger.info('AI model response: $result');

        if (result['is_anomaly']) {
          // Set anomaly in Firebase
          await _firebaseService.setAnomaly(true);
          setState(() {
            hasAnomaly = true;
            hasError = false;
            statusMessage =
                'Anomaly Detected: ${(result['anomaly_probability'] * 100).toStringAsFixed(1)}%';
          });
          try {
            await audioPlayer.play(
              UrlSource(
                'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
              ),
            );
          } catch (e) {
            _logger.warning('Could not play alert sound: $e');
          }
        } else {
          // Set anomaly to false in Firebase
          await _firebaseService.setAnomaly(false);
          setState(() {
            hasAnomaly = false;
            hasError = false;
            statusMessage = 'No Anomaly Detected';
          });
        }
      } else {
        _logger.severe('Error from AI model: ${response.statusCode}');
        _logger.severe('Response body: ${response.body}');
        setState(() {
          hasError = true;
          statusMessage = 'Error checking anomalies: ${response.statusCode}';
        });
      }
    } catch (e, stackTrace) {
      _logger.severe(
        'Error connecting to AI model: ${e.toString()}',
        e,
        stackTrace,
      );
      setState(() {
        hasError = true;
        statusMessage = 'Error connecting to AI model: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Monitor'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      HistoryPage(healthHistory: healthHistory),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.local_hospital),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HospitalsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _fetchData,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.0,
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          children: [
                            HealthCard(
                              title: 'Heart Rate',
                              value:
                                  '${healthData['heart_rate'].toStringAsFixed(1)}',
                              unit: 'BPM',
                              icon: Icons.favorite,
                              color: hasError ? Colors.grey : Colors.red,
                            ),
                            HealthCard(
                              title: 'SpO2',
                              value: '${healthData['spo2'].toStringAsFixed(1)}',
                              unit: '%',
                              icon: Icons.bloodtype,
                              color: hasError ? Colors.grey : Colors.blue,
                            ),
                            HealthCard(
                              title: 'Temperature',
                              value:
                                  '${healthData['temperature'].toStringAsFixed(1)}',
                              unit: '°C',
                              icon: Icons.thermostat,
                              color: hasError ? Colors.grey : Colors.orange,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => _checkForAnomalies(healthData),
                        icon: const Icon(Icons.health_and_safety),
                        label: const Text('Check for Anomalies'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          backgroundColor:
                              hasAnomaly ? Colors.orange : Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: hasError
                      ? Colors.red.withOpacity(0.1)
                      : hasAnomaly
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? Colors.red
                        : hasAnomaly
                            ? Colors.orange
                            : Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasError
                          ? Icons.error
                          : hasAnomaly
                              ? Icons.warning
                              : Icons.check_circle,
                      color: hasError
                          ? Colors.red
                          : hasAnomaly
                              ? Colors.orange
                              : Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: hasError
                              ? Colors.red
                              : hasAnomaly
                                  ? Colors.orange
                                  : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      TextSpan(text: 'Developed for '),
                      TextSpan(
                        text: 'Smart Bengal Hackathon',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' 2025 by Team '),
                      TextSpan(
                        text: 'IT_Peoples',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
