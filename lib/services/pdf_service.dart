import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/pressure_record.dart';

class PdfService {
  static Future<void> createAndShareReport(
      List<PressureRecord> records, String userName, int age) async {
    final pdf = pw.Document();

    try {
      // 1. Загружаем шрифты
      final fontData =
          await rootBundle.load("assets/images/fonts/Roboto-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);
      final boldFontData =
          await rootBundle.load("assets/images/fonts/Roboto-Bold.ttf");
      final ttfBold = pw.Font.ttf(boldFontData);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Дневник контроля давления: $userName',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Paragraph(
                text: 'Возраст: $age лет',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.Paragraph(
                text:
                    'Дата выгрузки: ${DateTime.now().toString().split('.')[0]}',
              ),
              pw.SizedBox(height: 20),
              if (records.isEmpty)
                pw.Center(
                    child: pw.Text('Записей пока нет',
                        style: const pw.TextStyle(fontSize: 18)))
              else
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.2), // Дата
                    1: const pw.FlexColumnWidth(1.5), // Давление
                    2: const pw.FlexColumnWidth(1), // Пульс
                    3: const pw.FlexColumnWidth(1.5), // Статус
                    4: const pw.FlexColumnWidth(
                        2.5), // Препарат (новая колонка)
                  },
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _buildCell('Дата', isHeader: true),
                        _buildCell('Давление', isHeader: true),
                        _buildCell('Пульс', isHeader: true),
                        _buildCell('Статус', isHeader: true),
                        _buildCell('Препарат', isHeader: true),
                      ],
                    ),
                    ...records.map((r) {
                      final bool isHigh = r.systolic > 140 || r.diastolic > 90;
                      final cellColor =
                          isHigh ? PdfColors.red100 : PdfColors.green100;

                      // Формируем строку препарата
                      final String pillInfo = (r.pillName != null ||
                              r.pillDose != null)
                          ? '${r.pillName ?? ''}${r.pillName != null && r.pillDose != null ? ', ' : ''}${r.pillDose ?? ''}'
                          : '-';

                      return pw.TableRow(
                        children: [
                          _buildCell(r.formattedDate),
                          _buildCell('${r.systolic}/${r.diastolic}',
                              color: cellColor),
                          _buildCell(r.pulse.toString()),
                          _buildCell(r.statusText),
                          _buildCell(pillInfo),
                        ],
                      );
                    }).toList(),
                  ],
                ),
            ];
          },
        ),
      );

      // 2. Сохранение
      final output = await getTemporaryDirectory();
      final String dateStr =
          DateTime.now().toString().split(' ')[0].replaceAll('-', '_');
      final String safeUserName =
          userName.replaceAll(RegExp(r'[^\w\sА-я]'), '_');
      final filePath = "${output.path}/Report_${safeUserName}_$dateStr.pdf";
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // 3. Поделиться
      await Share.shareXFiles([XFile(filePath)],
          text: 'Дневник давления пациента: $userName');
    } catch (e) {
      // Ошибки можно логировать здесь
    }
  }

  static pw.Widget _buildCell(String text,
      {bool isHeader = false, PdfColor? color}) {
    return pw.Container(
      color: color,
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10, // Чуть уменьшил шрифт, чтобы 5 колонок влезли комфортно
        ),
      ),
    );
  }
}
