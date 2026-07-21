import 'package:flutter/material.dart';

class AiBadge extends StatelessWidget {
  final bool isAutoApproved;
  final int? score;
  final String? reason;

  const AiBadge({
    super.key,
    required this.isAutoApproved,
    this.score,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAutoApproved ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAutoApproved ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAutoApproved ? Icons.check_circle : Icons.help_outline,
            size: 14,
            color: isAutoApproved ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isAutoApproved ? '🤖 Auto-Approved' : 'Manual Review',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isAutoApproved ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 4),
            Text(
              '($score%)',
              style: TextStyle(
                fontSize: 10,
                color: isAutoApproved ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}