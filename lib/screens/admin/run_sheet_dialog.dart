import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/gemini_service.dart';

class RunSheetDialog extends StatefulWidget {
  final Map<String, dynamic> requisition;

  const RunSheetDialog({super.key, required this.requisition});

  @override
  State<RunSheetDialog> createState() => _RunSheetDialogState();
}

class _RunSheetDialogState extends State<RunSheetDialog> {
  final _gemini = GeminiService();
  String? _runSheet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final req = widget.requisition;
      final sheet = await _gemini.generateRunSheet(
        purpose: req['purpose'] ?? 'College Event',
        venue: req['venue'] ?? '',
        date: req['booking_date'] ?? '',
        timeFrom: req['event_time_from'] ?? '',
        timeTo: req['event_time_to'] ?? '',
        expectedStrength: req['expected_strength'] ?? '',
      );
      if (mounted) setState(() => _runSheet = sheet);
    } catch (e) {
      if (mounted) setState(() => _runSheet = 'Error generating run sheet: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('AI Run Sheet Generator',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Generating run sheet with AI...'),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _runSheet ?? '',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13, height: 1.6),
                      ),
                    ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _generate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading || _runSheet == null
                          ? null
                          : () {
                              Clipboard.setData(
                                  ClipboardData(text: _runSheet!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard ✅')),
                              );
                            },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}