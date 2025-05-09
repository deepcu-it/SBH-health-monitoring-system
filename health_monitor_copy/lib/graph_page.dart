import 'package:flutter/material.dart';
import 'models/health_data.dart';
import 'package:fl_chart/fl_chart.dart';

class GraphPage extends StatelessWidget {
  final List<HealthData> healthHistory;
  const GraphPage({super.key, required this.healthHistory});

  @override
  Widget build(BuildContext context) {
    if (healthHistory.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Graphs')),
        body: const Center(child: Text('No data to display.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Health Data Graphs')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChart('Heart Rate (bpm)', Colors.red, (d) => d.heartRate),
              const SizedBox(height: 32),
              _buildChart('SpO2 (%)', Colors.blue, (d) => d.spo2),
              const SizedBox(height: 32),
              _buildChart(
                  'Temperature (°C)', Colors.orange, (d) => d.temperature),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(
      String title, Color color, double Function(HealthData) getValue) {
    final spots = List.generate(
      healthHistory.length,
      (i) => FlSpot(i.toDouble(), getValue(healthHistory[i])),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
