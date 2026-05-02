import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:babushka_pressure/widgets/pressure_chart.dart';
import 'package:babushka_pressure/widgets/record_tile.dart';

import 'models/pressure_record.dart';
import 'services/pdf_service.dart';
import 'screens/add_record_screen.dart';
import 'screens/profile_selection_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  runApp(const PressureApp());
}

class PressureApp extends StatefulWidget {
  const PressureApp({super.key});

  @override
  State<PressureApp> createState() => _PressureAppState();
}

class _PressureAppState extends State<PressureApp> {
  // Сохраняем userId в состоянии приложения
  int? _currentUserId;

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
      home: _currentUserId == null
          ? const ProfileSelectionScreen()
          : MainHistoryScreen(userId: _currentUserId!),
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final userId = settings.arguments as int;
          _currentUserId = userId;
          return MaterialPageRoute(
            builder: (context) => MainHistoryScreen(userId: userId),
          );
        }
        if (settings.name == '/profile') {
          _currentUserId = null;
          return MaterialPageRoute(
            builder: (context) => const ProfileSelectionScreen(),
          );
        }
        return null;
      },
    );
  }
}

class MainHistoryScreen extends StatefulWidget {
  final int userId;
  const MainHistoryScreen({super.key, required this.userId});

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
      _recordsFuture =
          DatabaseService.instance.getRecords(userId: widget.userId);
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

  Future<void> _exportPdfReport(BuildContext context) async {
    try {
      final records =
          await DatabaseService.instance.getRecords(userId: widget.userId);
      final users = await DatabaseService.instance.getUsers();
      final user = users.firstWhere((u) => u['id'] == widget.userId);
      final userName = user['name'] ?? 'Пациент';
      final userAge = user['age'] ?? 0;
      final targetSys = user['targetSystolic'] ?? 120;
      final targetDia = user['targetDiastolic'] ?? 80;
      await PdfService.createAndShareReport(
          records, userName, userAge, targetSys, targetDia);
    } catch (e) {
      if (!context.mounted) return; // Вот ПРАВИЛЬНОЕ место для проверки
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при экспорте: \$e')),
      );
    }
  }

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
        title: FutureBuilder<Map<String, dynamic>>(
          future: DatabaseService.instance.getUsers().then(
              (users) => users.firstWhere((u) => u['id'] == widget.userId)),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Text(snapshot.data!["name"],
                  style: const TextStyle(fontSize: 20));
            }
            return const Text('');
          },
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: FutureBuilder<Map<String, dynamic>>(
            future: DatabaseService.instance.getUsers().then(
                (users) => users.firstWhere((u) => u['id'] == widget.userId)),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final user = snapshot.data!;
                return CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(
                    user['iconKey'] == 'male' ? Icons.male : Icons.female,
                    size: 20,
                    color: Colors.white,
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Поделиться отчетом',
            onPressed: () => _exportPdfReport(context),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Статистика',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StatisticsScreen(
                  recordsFuture: DatabaseService.instance
                      .getRecords(userId: widget.userId),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.switch_account,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text('Сменить профиль'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline,
                        color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text('Справка'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'switch':
                  Navigator.pushReplacementNamed(context, '/profile');
                  break;
                case 'help':
                  _showHelpDialog(context);
                  break;
              }
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddRecordScreen(userId: widget.userId),
            ),
          );
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
    return RecordTile(
      record: record,
      timeFormat: _timeFormat,
      confirmDelete: _confirmDelete,
      deleteRecord: _deleteRecord,
    );
  }

  // --- Логика списка ---
  Map<DateTime, List<PressureRecord>> _groupByDay(
      List<PressureRecord> records) {
    return records.fold(<DateTime, List<PressureRecord>>{}, (map, r) {
      final day = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
      (map[day] ??= []).add(r);
      return map;
    });
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
