import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pressure_record/widgets/pressure_chart.dart';

import 'models/pressure_record.dart';
import 'screens/add_record_screen.dart';
import 'services/database_service.dart';
import 'services/pdf_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  runApp(const PressureApp());
}

class PressureApp extends StatelessWidget {
  const PressureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Моё Давление',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 20),
          bodyMedium: TextStyle(fontSize: 18),
        ),
      ),
      home: const MainHistoryScreen(),
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
  final _dateHeaderFormat = DateFormat('dd MMMM yyyy', 'ru');
  final _timeFormat = DateFormat('HH:mm');

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

  // Удаление записи
  Future<void> _deleteRecord(int id) async {
    await DatabaseService.instance.deleteRecord(id);
    _refreshRecords();
  }

  // Диалог подтверждения удаления
  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить замер?'),
        content: const Text('Запись будет удалена навсегда.'),
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

  // Окно помощи
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Как пользоваться?"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: Icon(Icons.share, color: Colors.teal),
                title: Text("Отправить отчет врачу")),
            ListTile(
                leading: Icon(Icons.bar_chart, color: Colors.teal),
                title: Text("График аналитики")),
            ListTile(
                leading: Icon(Icons.swipe_left, color: Colors.red),
                title: Text("Свайп влево — удалить")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ПОНЯТНО"))
        ],
      ),
    );
  }

  (Color, String) _getPressureStatus(PressureRecord r) {
    if (r.systolic >= 140 || r.diastolic >= 90) return (Colors.red, "ВЫСОКОЕ");
    if (r.systolic >= 130 || r.diastolic >= 85) {
      return (Colors.orange, "ПОВЫШ.");
    }
    if (r.systolic >= 110 && r.diastolic >= 70) return (Colors.green, "НОРМА");
    return (Colors.blue, "НИЗКОЕ");
  }

  PressureRecord? _calculateTodayAverage(List<PressureRecord> records) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои замеры',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final records = await _recordsFuture;
              if (records.isNotEmpty) {
                await PdfService.createAndShareReport(records);
              }
            },
          ),
          // ВОТ ОН, ВОПРОСИК!
          IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context)),
          IconButton(
            icon: const Icon(Icons.bar_chart, size: 30),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        StatisticsScreen(recordsFuture: _recordsFuture))),
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
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.monitor_heart,
                      size: 100, color: Colors.teal.withAlpha(70)),
                  const Text("Записей нет.\nНажмите кнопку ниже.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey))
                ]));
          }
          final avg = _calculateTodayAverage(records);
          final grouped = _groupByDay(records);

          return Column(
            children: [
              if (avg != null) _buildAverageCard(avg),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _listItemCount(grouped),
                  itemBuilder: (context, index) =>
                      _buildGroupedItem(grouped, index),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AddRecordScreen()));
          _refreshRecords();
        },
        label: const Text('ДОБАВИТЬ ЗАМЕР',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- Карточка свайпа и удаления ---
  Widget _buildRecordTile(PressureRecord record) {
    final (color, status) = _getPressureStatus(record);
    return Dismissible(
      key: Key(record.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) => _deleteRecord(record.id!),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text("${record.systolic} / ${record.diastolic}",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Пульс: ${record.pulse}   •   ${_timeFormat.format(record.dateTime)}",
              ),
              // БЛОК ЛЕКАРСТВ: показываем только если есть данные
              if (record.pillName != null || record.pillDose != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.medication,
                          size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${record.pillName ?? ''}${record.pillName != null && record.pillDose != null ? ', ' : ''}${record.pillDose ?? ''}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.teal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, color: color, size: 28),
              Text(status,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Логика списка ---
  Map<DateTime, List<PressureRecord>> _groupByDay(
      List<PressureRecord> records) {
    final map = <DateTime, List<PressureRecord>>{};
    for (final r in records) {
      final day = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
      map.putIfAbsent(day, () => []).add(r);
    }
    return map;
  }

  int _listItemCount(Map<DateTime, List<PressureRecord>> grouped) {
    int count = 0;
    grouped.forEach((day, records) => count += 1 + records.length);
    return count;
  }

  Widget _buildGroupedItem(
      Map<DateTime, List<PressureRecord>> grouped, int index) {
    int currentIdx = 0;
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (var day in sortedDays) {
      if (currentIdx == index) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_dateHeaderFormat.format(day),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.teal)));
      }
      currentIdx++;
      for (var record in grouped[day]!) {
        if (currentIdx == index) return _buildRecordTile(record);
        currentIdx++;
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildAverageCard(PressureRecord avg) {
    return Card(
      color: Colors.teal.shade50,
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.teal.shade100)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [
              Text("${avg.systolic}/${avg.diastolic}",
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const Text("Среднее")
            ]),
            Column(children: [
              Text("${avg.pulse}",
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const Text("Пульс")
            ]),
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  final Future<List<PressureRecord>> recordsFuture;
  const StatisticsScreen({super.key, required this.recordsFuture});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Статистика")),
      body: FutureBuilder<List<PressureRecord>>(
        future: recordsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return PressureChart(records: snapshot.data!);
        },
      ),
    );
  }
}
