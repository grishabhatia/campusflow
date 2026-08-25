import 'package:flutter/material.dart';

class ApprovalPopupDialog extends StatelessWidget {
  final String eventName;
  final String venue;
  final String date;
  final String time;
  final int aiScore;
  final String aiReason;

  const ApprovalPopupDialog({
    super.key,
    required this.eventName,
    required this.venue,
    required this.date,
    required this.time,
    required this.aiScore,
    required this.aiReason,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 10),
          Text(
            '✅ Auto-Approved!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your event has been automatically approved by AI!',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.event, 'Event:', eventName),
                _infoRow(Icons.location_on, 'Venue:', venue),
                _infoRow(Icons.calendar_today, 'Date:', date),
                _infoRow(Icons.access_time, 'Time:', time),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ✅ Score removed
          const Text(
            '✅ Auto-approved by AI. No clash detected.',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '📧 A confirmation email has been sent to your registered email.',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Great, Thanks! 😊'),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}