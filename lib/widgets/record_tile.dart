import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import "../models/pressure_record.dart";

class RecordTile extends StatelessWidget {
  final PressureRecord record;
  final DateFormat timeFormat;
  final Function(BuildContext) confirmDelete;
  final Function(int) deleteRecord;

  const RecordTile({
    super.key,
    required this.record,
    required this.timeFormat,
    required this.confirmDelete,
    required this.deleteRecord,
  });

  (Color, String) _getPressureStatus(PressureRecord r) {
    if (r.systolic >= 140 || r.diastolic >= 90) return (Colors.red, "ВЫСОКОЕ");
    if (r.systolic >= 130 || r.diastolic >= 85) {
      return (Colors.orange, "ПОВЫШ.");
    }
    if (r.systolic >= 110 && r.diastolic >= 70) return (Colors.green, "НОРМА");
    return (Colors.blue, "НИЗКОЕ");
  }

  @override
  Widget build(BuildContext context) {
    final (color, status) = _getPressureStatus(record);
    return Dismissible(
      key: Key(record.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => confirmDelete(context),
      onDismissed: (direction) => deleteRecord(record.id!),
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
                "Пульс: ${record.pulse}   •   ${timeFormat.format(record.dateTime)}",
              ),
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
}
