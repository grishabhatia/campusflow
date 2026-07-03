import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import 'admin_service.dart';

class ExcelService {
  final _adminService = AdminService();

  Future<void> exportEventsToExcel() async {
    final events = await _adminService.getAllEvents();

    final excel = Excel.createExcel();
    final sheet = excel['Events Report'];

    // ─── Header row ────────────────────────────────────────────────────
    final headers = [
      'Event Name', 'Organization', 'Organizer',
      'Date', 'Start Time', 'End Time',
      'Room', 'Building', 'Expected Crowd',
      'Status', 'Special Instructions',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // ─── Data rows ─────────────────────────────────────────────────────
    for (int rowIdx = 0; rowIdx < events.length; rowIdx++) {
      final e = events[rowIdx];
      final room = e['rooms'] as Map<String, dynamic>?;
      final user = e['users'] as Map<String, dynamic>?;

      final rowData = [
        e['event_name'] ?? '',
        e['organization'] ?? '',
        user?['name'] ?? '',
        e['event_date'] ?? '',
        AdminService.minutesToTime(e['start_time'] ?? 0),
        AdminService.minutesToTime(e['end_time'] ?? 0),
        room?['room_name'] ?? '',
        room?['building'] ?? '',
        '${e['expected_crowd'] ?? 0}',
        (e['status'] ?? '').toUpperCase(),
        e['special_instructions'] ?? '',
      ];

      for (int colIdx = 0; colIdx < rowData.length; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIdx,
            rowIndex: rowIdx + 1,
          ),
        );
        cell.value = TextCellValue(rowData[colIdx]);

        // Alternating row colors
        if (rowIdx % 2 == 0) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
          );
        }
      }
    }

    // ─── Set column widths ─────────────────────────────────────────────
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 22);
    sheet.setColumnWidth(7, 18);
    sheet.setColumnWidth(8, 16);
    sheet.setColumnWidth(9, 12);
    sheet.setColumnWidth(10, 30);

    // ─── Download (web) ────────────────────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encoding failed');

    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'campusflow_events_${_todayString()}.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}