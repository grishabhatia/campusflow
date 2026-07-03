import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class ClashReportWidget extends StatefulWidget {
  final Map<String, dynamic> pendingEvent;

  const ClashReportWidget({super.key, required this.pendingEvent});

  @override
  State<ClashReportWidget> createState() => _ClashReportWidgetState();
}

class _ClashReportWidgetState extends State<ClashReportWidget> {
  final _adminService = AdminService();
  List<Map<String, dynamic>>? _clashes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkClashes();
  }

  Future<void> _checkClashes() async {
    try {
      final clashes = await _adminService.detectClashes(widget.pendingEvent);
      if (mounted) setState(() { _clashes = clashes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _clashes = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Row(
        children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          const SizedBox(width: 8),
          Text('Checking clashes...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      );
    }

    final hasClash = _clashes != null && _clashes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: hasClash
                ? Colors.red.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasClash ? Colors.red.shade300 : Colors.green.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasClash ? Icons.warning_amber_rounded : Icons.check_circle,
                size: 14,
                color: hasClash ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                hasClash ? '⚠️ Clash Detected' : '✅ No Clashes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasClash ? Colors.red[700] : Colors.green[700],
                ),
              ),
            ],
          ),
        ),

        // Clash details
        if (hasClash) ...[
          const SizedBox(height: 6),
          ..._clashes!.map((clash) {
            final room = clash['rooms'];
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '  Room occupied: ${AdminService.minutesToTime(clash['start_time'])} → ${AdminService.minutesToTime(clash['end_time'])} by "${clash['event_name']}"',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}