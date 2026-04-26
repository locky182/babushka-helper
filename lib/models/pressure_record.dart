import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PressureStatus { normal, warning, high, low }

class PressureRecord {
  final int? id;
  final int systolic; // Верхнее
  final int diastolic; // Нижнее
  final int pulse;
  final DateTime dateTime;
  final String? pillName; // Название лекарства
  final String? pillDose; // Дозировка

  PressureRecord({
    this.id,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.dateTime,
    this.pillName,
    this.pillDose,
  });

  // Конвертация в Map для БД (sqflite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'dateTime': dateTime.toIso8601String(),
      'pillName': pillName,
      'pillDose': pillDose,
    };
  }

  // Создание объекта из данных БД
  factory PressureRecord.fromMap(Map<String, dynamic> map) {
    return PressureRecord(
      id: map['id'],
      systolic: map['systolic'],
      diastolic: map['diastolic'],
      pulse: map['pulse'],
      dateTime: DateTime.parse(map['dateTime']),
      pillName: map['pillName'],
      pillDose: map['pillDose'],
    );
  }

  // Геттер для красивого вывода даты
  String get formattedDate => DateFormat('dd.MM.yyyy, HH:mm').format(dateTime);

  /// «Светофор»: быстрая оценка по клиническим порогам.
  PressureStatus get status {
    if (systolic < 100 || diastolic < 60) {
      return PressureStatus.low;
    }
    if (systolic >= 140 || diastolic >= 90) {
      return PressureStatus.high;
    }
    if (systolic >= 130 || diastolic >= 85) {
      return PressureStatus.warning;
    }
    return PressureStatus.normal;
  }

  Color get statusColor {
    switch (status) {
      case PressureStatus.high:
        return Colors.red;
      case PressureStatus.warning:
        return Colors.orange;
      case PressureStatus.low:
        return Colors.blue;
      case PressureStatus.normal:
        return Colors.green;
    }
  }

  String get statusText {
    switch (status) {
      case PressureStatus.high:
        return 'ВЫСОК.';
      case PressureStatus.warning:
        return 'ПОВЫШ.';
      case PressureStatus.low:
        return 'ПОНИЖ.';
      case PressureStatus.normal:
        return 'НОРМА';
    }
  }

  bool get isHigh => status == PressureStatus.high;
}
