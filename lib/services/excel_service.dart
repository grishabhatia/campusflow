import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import 'admin_service.dart';

class ExcelService {
  final _adminService = AdminService();

  Future<void> exportToExcel() async {
    final reqs = await _adminService.getAllRequisitions();

    final excel = Excel.createExcel();
    final sheet = excel['Requisitions Report'];

    // ─── Headers ───────────────────────────────────────────────────────
    final headers = [
      'Venue', 'Purpose', 'Organizer', 'Email',
      'Booking Date', 'Booking Time',
      'Event From', 'Event To',
      'Expected Strength', 'No. of Slots',
      'Status', 'Extra Furniture',
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
    for (int rowIdx = 0; rowIdx < reqs.length; rowIdx++) {
      final r = reqs[rowIdx];
      final user = r['users'] as Map<String, dynamic>?;
      final slots = (r['slots'] as List?)?.length ?? 0;

      final rowData = [
        r['venue'] ?? '',
        r['purpose'] ?? '',
        user?['name'] ?? '',
        user?['email'] ?? '',
        r['booking_date'] ?? '',
        r['booking_time'] ?? '',
        r['event_time_from'] ?? '',
        r['event_time_to'] ?? '',
        r['expected_strength'] ?? '',
        '$slots',
        (r['status'] ?? '').toUpperCase(),
        r['extra_furniture'] ?? '',
      ];

      for (int colIdx = 0; colIdx < rowData.length; colIdx++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
              columnIndex: colIdx, rowIndex: rowIdx + 1),
        );
        cell.value = TextCellValue(rowData[colIdx]);
        if (rowIdx % 2 == 0) {
          cell.cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
          );
        }
      }
    }

    // ─── Column widths ─────────────────────────────────────────────────
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 25);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 12);
    sheet.setColumnWidth(8, 18);
    sheet.setColumnWidth(9, 12);
    sheet.setColumnWidth(10, 12);
    sheet.setColumnWidth(11, 20);

    // ─── Download ──────────────────────────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encoding failed');

    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
          'download',
          'campusflow_requisitions_${_today()}.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}