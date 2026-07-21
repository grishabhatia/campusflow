import 'package:flutter/material.dart';

class ClashPopupDialog extends StatelessWidget {
  final String eventName;
  final String roomName;
  final String eventDate;
  final String startTime;
  final String endTime;
  final List<Map<String, dynamic>> clashes;

  const ClashPopupDialog({
    super.key,
    required this.eventName,
    required this.roomName,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.clashes,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.warning, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text(
            '⚠️ Clash Detected!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your event "$eventName" clashes with another approved event in the same room.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📌 $roomName', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('📅 $eventDate'),
                  Text('🕐 $startTime - $endTime'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Clash with:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...clashes.map((clash) => Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${clash['event_name']} (${formatTime(clash['start_time'])} - ${formatTime(clash['end_time'])})',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 8),
            const Text(
              '💡 Please choose another room or time.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to clash details
            Navigator.pushNamed(context, '/clash-details', arguments: clashes);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('View Clashing Event'),
        ),
      ],
    );
  }

  String formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${min.toString().padLeft(2, '0')} $period';
  }
}