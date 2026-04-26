import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Progress")),
      body: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(1, 60),
                FlSpot(2, 65),
                FlSpot(3, 70),
              ],
            )
          ],
        ),
      ),
    );
  }
}