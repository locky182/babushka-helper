import 'package:flutter/material.dart';

import '../models/pressure_record.dart';
import '../services/database_service.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _pillNameController = TextEditingController();
  final _pillDoseController = TextEditingController();

  // Начальный список популярных лекарств
  List<String> _dynamicSuggestions = [
    'Лозартан',
    'Эналаприл',
    'Каптоприл',
    'Бисопролол',
    'Амлодипин',
    'Лизиноприл'
  ];

  late DateTime _measurementTime;

  @override
  void initState() {
    super.initState();
    _measurementTime = DateTime.now();
    _loadPillHistory(); // Загружаем историю при входе
  }

  // Метод, который вытягивает уже введенные лекарства из базы
  Future<void> _loadPillHistory() async {
    final records = await DatabaseService.instance.getRecords();
    // Собираем уникальные названия препаратов из истории
    final historyPills = records
        .map((r) => r.pillName)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet();

    setState(() {
      // Объединяем стандартный список с историей пользователя
      _dynamicSuggestions = {..._dynamicSuggestions, ...historyPills}.toList();
    });
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    _pillNameController.dispose();
    _pillDoseController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _onSave() async {
    // Сначала проверяем валидацию формы
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Используем tryParse и ?? 0, чтобы приложение никогда не падало из-за пустых строк
    final record = PressureRecord(
      systolic: int.tryParse(_systolicController.text) ?? 0,
      diastolic: int.tryParse(_diastolicController.text) ?? 0,
      pulse: int.tryParse(_pulseController.text) ?? 0,
      dateTime: _measurementTime,
      pillName:
          _pillNameController.text.isEmpty ? null : _pillNameController.text,
      pillDose:
          _pillDoseController.text.isEmpty ? null : _pillDoseController.text,
    );

    await DatabaseService.instance.insertRecord(record);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый замер')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Поля давления (сократил для краткости, оставь свои валидаторы)
            TextFormField(
              controller: _systolicController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Верхнее'),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _diastolicController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Нижнее'),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Пульс'),
              style: const TextStyle(fontSize: 24),
            ),
            const Divider(height: 40),

            const Text("Принятое лекарство",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),

            // УМНЫЙ АВТОКОМПЛИТ
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textValue) {
                if (textValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _dynamicSuggestions.where((option) => option
                    .toLowerCase()
                    .contains(textValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _pillNameController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                // Если мы открыли экран для редактирования или просто вводим
                // связываем системный контроллер с нашим
                controller.addListener(() {
                  _pillNameController.text = controller.text;
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: _decoration('Название препарата',
                      icon: Icons.medication_outlined),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pillDoseController,
              decoration:
                  _decoration('Дозировка', icon: Icons.monitor_weight_outlined),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'СОХРАНИТЬ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
