import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_saver/file_saver.dart';

class ExcelService {
  /// ✅ Approved events ko Excel mein export karo
  /// Sirf woh events jinka registrar_approved = true hai
  Future<void> exportApprovedEvents() async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 Excel export started...');

      // ✅ Sirf fully approved events fetch karo
      final response = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .eq('registrar_approved', true)
          .order('created_at', ascending: false);

      final events = List<Map<String, dynamic>>.from(response);

      debugPrint('📋 Total approved events: ${events.length}');

      if (events.isEmpty) {
        throw Exception('Koi approved event nahi hai Excel banane ke liye');
      }

      // ✅ Excel workbook banao
      final excel = Excel.createExcel();
      final sheet = excel['Approved Events'];

      // ✅ Header row
      sheet.appendRow([
        TextCellValue('Event Name'),
        TextCellValue('Coordinator Name'),
        TextCellValue('Phone No.'),
        TextCellValue('Department'),
        TextCellValue('Department Email'),
        TextCellValue('Venue'),
        TextCellValue('Event Date'),
        TextCellValue('Event Time'),
        TextCellValue('Requested By'),
        TextCellValue('Approved At'),
      ]);

      // ✅ Header bold karo
      for (int i = 0; i < 10; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      // ✅ Department emails map (same as reminder_service)
      const deptEmails = {
        'CSE': '07vaishnavi.official@gmail.com',
        'Civil': 'grishabhatia2@gmail.com',
      };

      // ✅ Data rows add karo
      for (final event in events) {
        final dept = event['department'] ?? 'N/A';
        final deptEmail = deptEmails[dept] ?? 'N/A';

        // Signatures se coordinator info nikalo
        final sigs = event['signatures'] as Map<String, dynamic>?;
        final coordinatorName = sigs?['initiated_name'] ?? 'N/A';
        final coordinatorPhone = sigs?['initiated_phone'] ?? 'N/A';

        sheet.appendRow([
          TextCellValue(event['purpose'] ?? 'N/A'),
          TextCellValue(coordinatorName),
          TextCellValue(coordinatorPhone),
          TextCellValue(dept),
          TextCellValue(deptEmail),
          TextCellValue(event['venue'] ?? 'N/A'),
          TextCellValue(event['booking_date'] ?? 'N/A'),
          TextCellValue(
            '${event['event_time_from'] ?? ''} - ${event['event_time_to'] ?? ''}',
          ),
          TextCellValue(event['user_email'] ?? 'N/A'),
          TextCellValue(event['registrar_approved_at'] ?? 'N/A'),
        ]);
      }

      // ✅ Column widths set karo (optional)
      sheet.setColumnWidth(0, 30);
      sheet.setColumnWidth(1, 25);
      sheet.setColumnWidth(4, 30);
      sheet.setColumnWidth(5, 25);

      // ✅ File save karo
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encode failed');

      final fileName =
          'Approved_Events_${DateTime.now().toIso8601String().split('T').first}';

      // ✅ Web + Desktop + Mobile sab pe download
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      debugPrint('✅ Excel downloaded: $fileName.xlsx');
    } catch (e) {
      debugPrint('❌ Excel export error: $e');
      rethrow;
    }
  }
}