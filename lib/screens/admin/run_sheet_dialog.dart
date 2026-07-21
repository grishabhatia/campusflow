import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';

class RunSheetDialog extends StatefulWidget {
  final Map<String, dynamic> event;

  const RunSheetDialog({super.key, required this.event});

  @override
  State<RunSheetDialog> createState() => _RunSheetDialogState();
}

class _RunSheetDialogState extends State<RunSheetDialog> {
  String? _runSheet;
  bool _isLoading = true;
  final GeminiService _gemini = GeminiService('YOUR_GEMINI_API_KEY'); // ✅ API key pass karo

  @override
  void initState() {
    super.initState();
    _generateRunSheet();
  }

  Future<void> _generateRunSheet() async {
    try {
      final prompt = '''
Generate a detailed event run sheet for:
Event: ${widget.event['purpose'] ?? 'N/A'}
Date: ${widget.event['event_date'] ?? 'N/A'}
Time: ${widget.event['start_time'] ?? 'N/A'} - ${widget.event['end_time'] ?? 'N/A'}
Venue: ${widget.event['venue'] ?? 'N/A'}
Expected Crowd: ${widget.event['expected_strength'] ?? 'N/A'}

Format as a timeline with 15-minute intervals.
Include: Registration, Welcome, Main Event, Break, Q&A, Closing.
''';

      final response = await _gemini.generateContent(prompt);
      setState(() => _runSheet = response);
    } catch (e) {
      // Fallback template
      setState(() => _runSheet = '''
6:00 PM - Registration & Check-in
6:15 PM - Welcome Address
6:30 PM - Main Event Starts
7:30 PM - Break (Refreshments)
7:45 PM - Event Resumes
8:45 PM - Closing Remarks
9:00 PM - Event Ends
''');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('📋 Event Run Sheet'),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Text(
                  _runSheet ?? 'No content',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            // Copy to clipboard
          },
          child: const Text('📋 Copy'),
        ),
      ],
    );
  }
}