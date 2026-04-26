import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  // Новые контроллеры для лекарств
  final _pillNameController = TextEditingController();
  final _pillDoseController = TextEditingController();

  late DateTime _measurementTime;

  static const _fieldStyle = TextStyle(fontSize: 24);
  static const _fieldPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 20,
  );

  @override
  void initState() {
    super.initState();
    _measurementTime = DateTime.now();
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

  // Валидаторы оставляем прежними...
  String? _validateSystolic(String? value) {
    if (value == null || value.isEmpty) return 'Введите систолическое давление';
    final n = int.tryParse(value);
    if (n == null) return 'Укажите целое число';
    if (n < 70 || n > 250) return 'Допустимо от 70 до 250';
    return null;
  }

  String? _validateDiastolic(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите диастолическое давление';
    }
    final n = int.tryParse(value);
    if (n == null) return 'Укажите целое число';
    if (n < 40 || n > 150) return 'Допустимо от 40 до 150';
    return null;
  }

  String? _validatePulse(String? value) {
    if (value == null || value.isEmpty) return 'Введите пульс';
    final n = int.tryParse(value);
    if (n == null) return 'Укажите целое число';
    if (n < 30 || n > 200) return 'Допустимо от 30 до 200';
    return null;
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      contentPadding: _fieldPadding,
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measurementTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measurementTime),
    );
    if (!mounted || time == null) return;

    setState(() {
      _measurementTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final record = PressureRecord(
      systolic: int.parse(_systolicController.text),
      diastolic: int.parse(_diastolicController.text),
      pulse: int.parse(_pulseController.text),
      dateTime: _measurementTime,
      // Сохраняем новые поля
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
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый замер'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _systolicController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: _fieldStyle,
              decoration: _decoration('Верхнее (Систолическое)'),
              validator: _validateSystolic,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _diastolicController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: _fieldStyle,
              decoration: _decoration('Нижнее (Диастолическое)'),
              validator: _validateDiastolic,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: _fieldStyle,
              decoration: _decoration('Пульс'),
              validator: _validatePulse,
              textInputAction: TextInputAction.next,
            ),

            // СЕКЦИЯ ЛЕКАРСТВ
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),
            const Text("Принятое лекарство (если было)",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 12),

            TextFormField(
              controller: _pillNameController,
              decoration: _decoration('Название препарата',
                  icon: Icons.medication_outlined),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pillDoseController,
              decoration: _decoration('Дозировка (напр. 50 мг)',
                  icon: Icons.monitor_weight_outlined),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                dateFormat.format(_measurementTime),
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _onSave,
                icon: const Icon(Icons.save_rounded, size: 28),
                label: const Text('СОХРАНИТЬ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
