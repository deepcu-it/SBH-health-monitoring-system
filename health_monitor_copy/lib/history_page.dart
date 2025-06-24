import 'package:flutter/material.dart';
import 'models/health_data.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'graph_page.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  final List<HealthData> healthHistory;

  const HistoryPage({super.key, required this.healthHistory});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool showOnlyAnomalies = false;
  String searchQuery = '';
  String selectedTimeRange = 'All';
  final List<String> timeRanges = [
    'All',
    'Today',
    'Last 7 Days',
    'Last 30 Days'
  ];

  List<HealthData> get filteredHistory {
    var filtered = widget.healthHistory;

    // Filter by anomaly
    if (showOnlyAnomalies) {
      filtered = filtered.where((data) => data.hasAnomaly).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((data) {
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(data.timestamp);
        return dateStr.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by time range
    final now = DateTime.now();
    switch (selectedTimeRange) {
      case 'Today':
        filtered = filtered
            .where((data) =>
                data.timestamp.year == now.year &&
                data.timestamp.month == now.month &&
                data.timestamp.day == now.day)
            .toList();
        break;
      case 'Last 7 Days':
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        filtered = filtered
            .where((data) => data.timestamp.isAfter(sevenDaysAgo))
            .toList();
        break;
      case 'Last 30 Days':
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));
        filtered = filtered
            .where((data) => data.timestamp.isAfter(thirtyDaysAgo))
            .toList();
        break;
    }

    return filtered;
  }

  Future<void> _downloadCSV(BuildContext context) async {
    if (filteredHistory.isEmpty) return;
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('Timestamp,Heart Rate,SpO2,Temperature,Anomaly');
    for (final data in filteredHistory) {
      csvBuffer.writeln(
        '${data.timestamp.toIso8601String()},${data.heartRate},${data.spo2},${data.temperature},${data.hasAnomaly ? 'Yes' : 'No'}',
      );
    }
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/health_history.csv';
    final file = File(path);
    await file.writeAsString(csvBuffer.toString());
    await Share.shareFiles([path], text: 'Health Data History');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health History'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download CSV',
            onPressed: () => _downloadCSV(context),
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            tooltip: 'View Graphs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GraphPage(healthHistory: filteredHistory),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by date...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Time Range Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: timeRanges.map((range) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(range),
                          selected: selectedTimeRange == range,
                          onSelected: (selected) {
                            setState(() {
                              selectedTimeRange = range;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Anomaly Filter
                Row(
                  children: [
                    const Text('Show only anomalies:'),
                    const SizedBox(width: 8),
                    Switch(
                      value: showOnlyAnomalies,
                      onChanged: (value) {
                        setState(() {
                          showOnlyAnomalies = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No history available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final data = filteredHistory[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: data.hasAnomaly
                              ? const BorderSide(color: Colors.red, width: 1)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: () {
                            // Show detailed view
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (context) => Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Detailed Health Data',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailRow(
                                      'Time',
                                      DateFormat('dd/MM/yyyy HH:mm:ss')
                                          .format(data.timestamp),
                                    ),
                                    _buildDetailRow(
                                      'Heart Rate',
                                      '${data.heartRate} bpm',
                                      color: Colors.red,
                                    ),
                                    _buildDetailRow(
                                      'SpO2',
                                      '${data.spo2}%',
                                      color: Colors.blue,
                                    ),
                                    _buildDetailRow(
                                      'Temperature',
                                      '${data.temperature.toStringAsFixed(2)}°C',
                                      color: Colors.orange,
                                    ),
                                    _buildDetailRow(
                                      'Status',
                                      data.hasAnomaly
                                          ? 'Anomaly Detected'
                                          : 'Normal',
                                      color: data.hasAnomaly
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm')
                                          .format(data.timestamp),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (data.hasAnomaly)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warning,
                                              color: Colors.red,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Anomaly',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildMetricColumn(
                                      'Heart Rate',
                                      '${data.heartRate}',
                                      'bpm',
                                      Colors.red,
                                    ),
                                    _buildMetricColumn(
                                      'SpO2',
                                      '${data.spo2}',
                                      '%',
                                      Colors.blue,
                                    ),
                                    _buildMetricColumn(
                                      'Temperature',
                                      '${data.temperature.toStringAsFixed(2)}',
                                      '°C',
                                      Colors.orange,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
      String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
