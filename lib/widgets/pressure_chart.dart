import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pressure_record/models/pressure_record.dart';

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

    // Сортируем записи по дате, чтобы график шел слева направо
    final sortedRecords = List<PressureRecord>.from(records)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Container(
      height: 350,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 20),
      child: LineChart(
        LineChartData(
          lineTouchData: _buildTouchData(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: _buildTitles(sortedRecords),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _generateLine(sortedRecords, isSystolic: true),
            _generateLine(sortedRecords, isSystolic: false),
          ],
          // Устанавливаем границы Y для стабильности картинки
          minY: 40,
          maxY: 220,
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
          // Используем твою логику цвета из модели для точек!
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
        color: isSystolic
            ? Colors.redAccent.withOpacity(0.05)
            : Colors.blueAccent.withOpacity(0.05),
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
            if (index < 0 || index >= sortedRecords.length)
              return const SizedBox();

            // Показываем дату только для каждой 3-й точки, чтобы не частить
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

  LineTouchData _buildTouchData() {
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (group) => Colors.white.withOpacity(0.9),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            return LineTooltipItem(
              '${spot.y.toInt()} мм рт.ст.',
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            );
          }).toList();
        },
      ),
    );
  }
}
