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
  TextEditingController? _activeController;
  String _lastWords = '';

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _pillNameController = TextEditingController();
  final _pillDoseController = TextEditingController();

  Future<void> _listenToField(TextEditingController controller) async {
    debugPrint('!!! ПИШУ В КОНТРОЛЛЕР: \\${controller.text}');
    try {
      await _speechToText.stop();
      if (!_speechToText.isAvailable) {
        await _speechToText.initialize();
      }
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Необходимо разрешение микрофона')),
        );
        return;
      }

      if (!_speechToText.isListening) {
        await _speechToText.initialize(
          onStatus: (status) => debugPrint('Status: \$status'),
          onError: (error) => debugPrint('Error: \$error'),
        );
      }

      await _speechToText.listen(
        localeId: "ru_RU",
        listenFor: const Duration(seconds: 5),
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
          if (result.finalResult && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Слышу: $_lastWords')),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Error in _listenToField: \$e');
    }
  }

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
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
            final lastWordsSnapshot =
                _lastWords; // Сохраняем текущее значение перед остановкой
            setState(() => _isListening = false);
            _speechToText.stop();

            // Извлекаем цифры из сохраненного значения
            if (lastWordsSnapshot.isNotEmpty) {
              final numbers = RegExp(r'\d+')
                  .allMatches(lastWordsSnapshot)
                  .map((m) => m.group(0)!)
                  .toList();

              if (numbers.isNotEmpty) {
                _systolicController.text =
                    numbers.last; // Берем последнее распознанное число
                if (numbers.length >= 2) {
                  _diastolicController.text = numbers[numbers.length - 2];
                }
                if (numbers.length >= 3) {
                  _pulseController.text = numbers[numbers.length - 3];
                }

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
            Row(
              children: [
                SizedBox(
                  width: 270,
                  child: TextFormField(
                    controller: _systolicController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration('Верхнее (Систола)'),
                    style: const TextStyle(fontSize: 21.12),
                    validator: _validateSystolic,
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onLongPressStart: (_) {
                    debugPrint('!!! СТАРТ УДЕРЖАНИЯ (СИСТОЛА)');
                    _lastWords = '';
                    setState(() => _activeController = _systolicController);
                    _listenToField(_systolicController);
                  },
                  onLongPressEnd: (_) {
                    final recognizedText = _lastWords;
                    _speechToText.stop();
                    final numbers = RegExp(r'\d+')
                        .allMatches(recognizedText)
                        .map((m) => m.group(0)!)
                        .toList();
                    if (numbers.isNotEmpty) {
                      _systolicController.text = numbers.last;
                    }
                    setState(() => _activeController = null);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeController == _systolicController
                          ? Colors.green
                          : Colors.blue,
                    ),
                    child: const Icon(Icons.mic, size: 28, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 270,
                  child: TextFormField(
                    controller: _diastolicController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration('Нижнее (Диастола)'),
                    style: const TextStyle(fontSize: 21.12),
                    validator: _validateDiastolic,
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onLongPressStart: (_) {
                    debugPrint('!!! СТАРТ УДЕРЖАНИЯ (ДИАСТОЛА)');
                    _lastWords = '';
                    setState(() => _activeController = _diastolicController);
                    _listenToField(_diastolicController);
                  },
                  onLongPressEnd: (_) {
                    final recognizedText = _lastWords;
                    _speechToText.stop();
                    final numbers = RegExp(r'\d+')
                        .allMatches(recognizedText)
                        .map((m) => m.group(0)!)
                        .toList();
                    if (numbers.isNotEmpty) {
                      _diastolicController.text = numbers.last;
                    }
                    setState(() => _activeController = null);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeController == _diastolicController
                          ? Colors.green
                          : Colors.blue,
                    ),
                    child: const Icon(Icons.mic, size: 24, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 270,
                  child: TextFormField(
                    controller: _pulseController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration('Пульс'),
                    style: const TextStyle(fontSize: 21.12),
                    validator: _validatePulse,
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onLongPressStart: (_) {
                    debugPrint('!!! СТАРТ УДЕРЖАНИЯ (ПУЛЬС)');
                    setState(() {
                      _lastWords = '';
                      _activeController = _pulseController;
                    });
                    _listenToField(_pulseController);
                  },
                  onLongPressEnd: (_) {
                    final recognizedText =
                        _lastWords; // Хватаем текст ДО остановки
                    _speechToText.stop();
                    final numbers = RegExp(r'\d+')
                        .allMatches(recognizedText)
                        .map((m) => m.group(0)!)
                        .toList();
                    if (numbers.isNotEmpty) {
                      _pulseController.text = numbers.last;
                    }
                    setState(() => _activeController = null);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeController == _pulseController
                          ? Colors.green
                          : Colors.blue,
                    ),
                    child: const Icon(Icons.mic, size: 24, color: Colors.white),
                  ),
                ),
              ],
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
