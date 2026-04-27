import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/pressure_record.dart';
import '../services/database_service.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final SpeechToText _speechToText = SpeechToText();

  bool _isListening = false;
  String _lastWords = '';

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _pillNameController = TextEditingController();
  final _pillDoseController = TextEditingController();

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
    _loadPillHistory();
  }

  Future<void> _loadPillHistory() async {
    final records = await DatabaseService.instance.getRecords();
    final historyPills = records
        .map((r) => r.pillName)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet();

    setState(() {
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

  // СТРОГИЕ ВАЛИДАТОРЫ
  String? _validateSystolic(String? value) {
    if (value == null || value.isEmpty) return 'Введите число';
    final n = int.tryParse(value);
    if (n == null) return 'Только цифры';
    if (n < 70 || n > 250) return 'Нужно от 70 до 250';
    return null;
  }

  String? _validateDiastolic(String? value) {
    if (value == null || value.isEmpty) return 'Введите число';
    final n = int.tryParse(value);
    if (n == null) return 'Только цифры';
    if (n < 40 || n > 150) return 'Нужно от 40 до 150';
    return null;
  }

  String? _validatePulse(String? value) {
    if (value == null || value.isEmpty) return 'Введите число';
    final n = int.tryParse(value);
    if (n == null) return 'Только цифры';
    if (n < 30 || n > 200) return 'Нужно от 30 до 200';
    return null;
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measurementTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    // 1. ПРОВЕРКА ПОСЛЕ ВЫБОРА ДАТЫ
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_measurementTime),
    );

    // 2. ПРОВЕРКА ПОСЛЕ ВЫБОРА ВРЕМЕНИ
    if (!mounted) return;
    if (time == null) return;

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
      pillName:
          _pillNameController.text.isEmpty ? null : _pillNameController.text,
      pillDose:
          _pillDoseController.text.isEmpty ? null : _pillDoseController.text,
    );

    await DatabaseService.instance.insertRecord(record);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _startListening() async {
    debugPrint('!!! ACTION: BUTTON CLICKED');
    try {
      if (_speechToText.isListening) {
        setState(() => _isListening = false);
        _speechToText.stop();
        return;
      }

      await Permission.microphone.request();

      await _speechToText.initialize(
        onStatus: (status) => debugPrint('!!! STT STATUS: \$status'),
        onError: (error) => debugPrint('!!! STT ERROR: \$error'),
      );

      // Проверка и запрос разрешения микрофона
      final micPermission = await Permission.microphone.request();
      if (!mounted) return;
      if (micPermission != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо разрешение микрофона')),
        );
        return;
      }

      // Инициализация сервиса распознавания
      debugPrint('Инициализация голосового ввода...');
      bool available = await _speechToText.initialize(
        onStatus: (status) => debugPrint('Статус: \\$status'),
        onError: (error) {
          debugPrint('Ошибка: \\$error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка распознавания: \\$error')),
            );
          }
        },
      );

      if (!available) {
        debugPrint('Сервис распознавания недоступен');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Голосовой ввод недоступен')),
          );
        }
        return;
      }

      // Начало прослушивания
      setState(() => _isListening = true);
      await _speechToText.listen(
        localeId: "ru_RU",
        onSoundLevelChange: (level) => debugPrint('Уровень звука: \$level'),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
        listenFor: const Duration(minutes: 10),
        onResult: (result) {
          if (!mounted) return;

          debugPrint('Распознано: \\${result.recognizedWords}');
          setState(() {
            _lastWords = result.recognizedWords;

            // Извлечение цифр из распознанного текста
            final numbers = RegExp(r'\d+')
                .allMatches(_lastWords)
                .map((m) => m.group(0)!)
                .toList();

            if (numbers.isNotEmpty) {
              _systolicController.text = numbers[0];
              if (numbers.length >= 2) _diastolicController.text = numbers[1];
              if (numbers.length >= 3) _pulseController.text = numbers[2];
              setState(() {});
            }

            if (numbers.length >= 2) {
              debugPrint('Пытаюсь вставить в поля: \$numbers');
              _systolicController.text = numbers[0];
              _diastolicController.text = numbers[1];
              if (numbers.length >= 3) {
                _pulseController.text = numbers[2];
              }

              // Автоматически остановить прослушивание после успешного ввода
              _speechToText.stop();
              setState(() {
                _isListening = false;
                _formKey.currentState?.validate();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Данные успешно введены')),
              );
            }
          });
        },
      );
    } catch (e) {
      debugPrint('Критическая ошибка: \\$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: \\$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Новый замер')),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isListening ? Colors.green : Colors.blue,
        ),
        child: GestureDetector(
          onLongPressStart: (_) {
            debugPrint('!!! СТАРТ УДЕРЖАНИЯ');
            _startListening();
          },
          onLongPressEnd: (_) {
            debugPrint('!!! КОНЕЦ УДЕРЖАНИЯ');
            setState(() => _isListening = false);

            // Простая логика извлечения цифр
            if (_lastWords.isNotEmpty) {
              final numbers = RegExp(r'\d+')
                  .allMatches(_lastWords)
                  .map((m) => m.group(0)!)
                  .toList();

              if (numbers.isNotEmpty) {
                _systolicController.text = numbers[0];
                if (numbers.length >= 2) _diastolicController.text = numbers[1];
                if (numbers.length >= 3) _pulseController.text = numbers[2];

                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Данные распознаны. Пожалуйста, проверьте правильность перед сохранением')),
                );
              }
            }
          },
          child: const Icon(Icons.mic, size: 36, color: Colors.white),
        ),
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
              decoration: _decoration('Верхнее (Систола)'),
              style: const TextStyle(fontSize: 24),
              validator: _validateSystolic,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _diastolicController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration('Нижнее (Диастола)'),
              style: const TextStyle(fontSize: 24),
              validator: _validateDiastolic,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _pulseController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration('Пульс'),
              style: const TextStyle(fontSize: 24),
              validator: _validatePulse,
            ),
            const SizedBox(height: 20),

            // Кнопка выбора времени
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.access_time),
              label: Text("Время: ${dateFormat.format(_measurementTime)}"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            const Divider(height: 40),
            const Text("Принятое лекарство",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),

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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('СОХРАНИТЬ',
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
