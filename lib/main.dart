import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pressure_record/widgets/pressure_chart.dart';
import 'package:pressure_record/screens/splash_screen.dart';

import 'models/pressure_record.dart';
import 'screens/add_record_screen.dart';
import 'services/database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PressureApp());
}

/// Расчет среднего за сегодня
PressureRecord? calculateTodayAverage(List<PressureRecord> records) {
  final today = DateTime.now();
  final todayRecords = records
      .where((r) =>
          r.dateTime.year == today.year &&
          r.dateTime.month == today.month &&
          r.dateTime.day == today.day)
      .toList();

  if (todayRecords.isEmpty) return null;

  int sys = 0, dia = 0, pul = 0;
  for (var r in todayRecords) {
    sys += r.systolic;
    dia += r.diastolic;
    pul += r.pulse;
  }

  return PressureRecord(
    systolic: (sys / todayRecords.length).round(),
    diastolic: (dia / todayRecords.length).round(),
    pulse: (pul / todayRecords.length).round(),
    dateTime: today,
  );
}

class PressureApp extends StatelessWidget {
  const PressureApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE57373),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Дневник Давления',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class MainHistoryScreen extends StatefulWidget {
  const MainHistoryScreen({super.key});

  @override
  State<MainHistoryScreen> createState() => _MainHistoryScreenState();
}

class _MainHistoryScreenState extends State<MainHistoryScreen> {
  late Future<List<PressureRecord>> _recordsFuture;

  static final _dateHeaderFormat = DateFormat('dd MMMM yyyy');
  static final _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _refreshRecords();
  }

  void _refreshRecords() {
    setState(() {
      _recordsFuture = DatabaseService.instance.getRecords();
    });
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Как пользоваться?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _helpItem(
                Icons.bar_chart, "Иконка сверху открывает график аналитики."),
            _helpItem(
                Icons.swipe_left, "Свайп влево по замеру удалит его из базы."),
            _helpItem(Icons.circle,
                "Цвета (синий,зеленый, желтый, красный) показывают уровень давления."),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Понятно"))
        ],
      ),
    );
  }

  Widget _helpItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Map<DateTime, List<PressureRecord>> _groupByDay(
      List<PressureRecord> records) {
    final map = <DateTime, List<PressureRecord>>{};
    for (final r in records) {
      final day = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
      map.putIfAbsent(day, () => []).add(r);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (var k in sortedKeys)
        k: map[k]!..sort((a, b) => b.dateTime.compareTo(a.dateTime))
    };
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить замер?'),
        content: const Text('Запись будет удалена безвозвратно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ОТМЕНА')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('УДАЛИТЬ')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои замеры'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 30), // Иконка графика
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      StatisticsScreen(recordsFuture: _recordsFuture),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<PressureRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text("Записей пока нет. Нажмите +"));
          }

          final avg = calculateTodayAverage(records);
          final grouped = _groupByDay(records);
          final days = grouped.keys.toList();

          return Column(
            children: [
              if (avg != null) _buildAverageCard(avg),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _listItemCount(grouped, days),
                  itemBuilder: (context, index) =>
                      _buildGroupedItem(context, grouped, days, index),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AddRecordScreen()));
          _refreshRecords();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  int _listItemCount(
      Map<DateTime, List<PressureRecord>> grouped, List<DateTime> days) {
    int count = 0;
    for (var day in days) {
      count += 1 + grouped[day]!.length;
    }
    return count;
  }

  Widget _buildGroupedItem(
      BuildContext context,
      Map<DateTime, List<PressureRecord>> grouped,
      List<DateTime> days,
      int index) {
    int currentIdx = 0;
    for (var day in days) {
      if (currentIdx == index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(_dateHeaderFormat.format(day),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor)),
        );
      }
      currentIdx++;
      for (var record in grouped[day]!) {
        if (currentIdx == index) {
          return Dismissible(
            key: Key(record.id.toString()),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(context),
            onDismissed: (_) async {
              await DatabaseService.instance.deleteRecord(record.id!);
              _refreshRecords();
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: _buildRecordTile(record),
          );
        }
        currentIdx++;
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildRecordTile(PressureRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.favorite_rounded,
          color: record.statusColor,
          size: 32,
        ),
        title: Text('${record.systolic} / ${record.diastolic}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Пульс: ${record.pulse} • ${_timeFormat.format(record.dateTime)}'),
        trailing: Text(record.statusText,
            style: TextStyle(
                color: record.statusColor, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAverageCard(PressureRecord avg) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      color: avg.statusColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: avg.statusColor, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("СРЕДНЕЕ ЗА СЕГОДНЯ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn("Давление", "${avg.systolic}/${avg.diastolic}",
                    avg.statusColor),
                _buildStatColumn("Пульс", "${avg.pulse}", Colors.black87),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  final Future<List<PressureRecord>> recordsFuture;
  const StatisticsScreen({super.key, required this.recordsFuture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Аналитика")),
      body: FutureBuilder<List<PressureRecord>>(
        future: recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text("Нет данных для анализа"));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Динамика давления",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Оборачиваем график в Expanded, чтобы он занял доступное место
                Expanded(
                  child: PressureChart(records: records),
                ),
                const SizedBox(height: 20),
                Text(
                  "Всего замеров: ${records.length}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
