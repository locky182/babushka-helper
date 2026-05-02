import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pressure_record.dart';

class PressureChart extends StatelessWidget {
  final List<PressureRecord> records;

  const PressureChart({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("Нет данных для анализа")),
      );
    }

    final sortedRecords = List<PressureRecord>.from(records)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // Рассчитываем средний пульс для определения цвета линии
    final avgPulse = sortedRecords.isEmpty
        ? 0
        : (sortedRecords.map((r) => r.pulse).reduce((a, b) => a + b) /
                sortedRecords.length)
            .round();
    final pulseColor = PressureRecord.getPulseColor(avgPulse);

    return SingleChildScrollView(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Давление (мм рт.ст.)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          _buildChart(
            records: sortedRecords,
            height: 300,
            minY: 40,
            maxY: 220,
            lineBarsData: [
              _generateLine(sortedRecords, isSystolic: true),
              _generateLine(sortedRecords, isSystolic: false),
            ],
            touchLabel: 'мм рт.ст.',
          ),
          const Divider(height: 40, thickness: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monitor_heart, color: pulseColor),
                const SizedBox(width: 8),
                const Text(
                  "Пульс (уд/мин)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          _buildChart(
            records: sortedRecords,
            height: 200,
            minY: 40,
            maxY: 160,
            lineBarsData: [
              _generatePulseLine(sortedRecords, pulseColor),
            ],
            touchLabel: 'уд/мин',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChart({
    required List<PressureRecord> records,
    required double height,
    required double minY,
    required double maxY,
    required List<LineChartBarData> lineBarsData,
    required String touchLabel,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 10),
      child: LineChart(
        LineChartData(
          lineTouchData: _buildTouchData(touchLabel),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: _buildTitles(records),
          borderData: FlBorderData(show: false),
          lineBarsData: lineBarsData,
          minY: minY,
          maxY: maxY,
        ),
      ),
    );
  }

  LineChartBarData _generateLine(List<PressureRecord> sortedRecords,
      {required bool isSystolic}) {
    return LineChartBarData(
      spots: sortedRecords.asMap().entries.map((entry) {
        final index = entry.key.toDouble();
        final value = isSystolic ? entry.value.systolic : entry.value.diastolic;
        return FlSpot(index, value.toDouble());
      }).toList(),
      isCurved: true,
      color: isSystolic ? Colors.redAccent : Colors.blueAccent,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: sortedRecords[index].statusColor,
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: (isSystolic ? Colors.redAccent : Colors.blueAccent)
            .withValues(alpha: 0.05),
      ),
    );
  }

  LineChartBarData _generatePulseLine(
      List<PressureRecord> sortedRecords, Color color) {
    return LineChartBarData(
      spots: sortedRecords.asMap().entries.map((entry) {
        final index = entry.key.toDouble();
        final value = entry.value.pulse;
        return FlSpot(index, value.toDouble());
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: PressureRecord.getPulseColor(sortedRecords[index].pulse),
            strokeWidth: 2,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }

  FlTitlesData _buildTitles(List<PressureRecord> sortedRecords) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => Text(
            value.toInt().toString(),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) {
            int index = value.toInt();
            if (index < 0 || index >= sortedRecords.length) {
              return const SizedBox();
            }

            if (sortedRecords.length > 5 &&
                index % (sortedRecords.length ~/ 3) != 0) {
              return const SizedBox();
            }

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                DateFormat('dd.MM').format(sortedRecords[index].dateTime),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(String label) {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (group) => Colors.white.withValues(alpha: 0.9),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              '${spot.y.toInt()} $label',
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            );
          }).toList();
        },
      ),
    );
  }
}
