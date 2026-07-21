import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // Get free key at: https://aistudio.google.com/app/apikey
  static const _apiKey = 'AQ.Ab8RN6KSb5sW29XfDBFoAo4SRVgxfEM4cZt_G4Ae67nlEEyreA';

  GenerativeModel? get _model => _apiKey != 'YOUR_GEMINI_API_KEY'
      ? GenerativeModel(model: 'gemini-pro', apiKey: _apiKey)
      : null;

  // ── Approval Decision ────────────────────────────────────────────────────
  Future<String> askApprovalDecision({
    required String purpose,
    required String date,
    required String timeFrom,
    required String timeTo,
    required String venue,
    required String strength,
  }) async {
    if (_model == null) return 'manual';
    try {
      final prompt = '''
Should this college event be approved?
Event: $purpose
Date: $date
Time: $timeFrom - $timeTo
Venue: $venue (Manav Rachna University)
Expected Attendees: $strength

Respond with ONLY one word: "approve" or "manual"
''';
      final response =
          await _model!.generateContent([Content.text(prompt)]);
      final text = (response.text ?? '').trim().toLowerCase();
      return text.contains('approve') ? 'approve' : 'manual';
    } catch (_) {
      return 'manual';
    }
  }

  // ── Run Sheet Generator ───────────────────────────────────────────────────
  Future<String> generateRunSheet({
    required String purpose,
    required String venue,
    required String date,
    required String timeFrom,
    required String timeTo,
    required String expectedStrength,
  }) async {
    if (_model == null) {
      return _templateRunSheet(
        purpose: purpose, venue: venue, date: date,
        timeFrom: timeFrom, timeTo: timeTo,
        expectedStrength: expectedStrength,
      );
    }
    try {
      final prompt = '''
Generate a detailed event run sheet with 15-minute intervals for:
Event: $purpose
Venue: $venue, Manav Rachna University
Date: $date
Time: $timeFrom to $timeTo
Expected Attendees: $expectedStrength

Include: Registration, Welcome, Main Activity, Break (if >2hrs), Closing.
Output only the run sheet timeline, no extra text.
''';
      final response =
          await _model!.generateContent([Content.text(prompt)]);
      return response.text ??
          _templateRunSheet(
            purpose: purpose, venue: venue, date: date,
            timeFrom: timeFrom, timeTo: timeTo,
            expectedStrength: expectedStrength,
          );
    } catch (_) {
      return _templateRunSheet(
        purpose: purpose, venue: venue, date: date,
        timeFrom: timeFrom, timeTo: timeTo,
        expectedStrength: expectedStrength,
      );
    }
  }

  // ── Venue Recommendation Reason ───────────────────────────────────────────
  String getVenueRecommendationReason({
    required int capacity,
    required int expectedStrength,
    required List<String> amenities,
  }) {
    final diff = capacity - expectedStrength;
    String suit;
    if (diff == 0)        suit = '🎯 Perfect match';
    else if (diff <= 20)  suit = '✅ Ideal fit';
    else if (diff <= 50)  suit = '👍 Good fit';
    else if (diff <= 100) suit = '📌 Adequate';
    else                  suit = '⚠️ Oversized';
    final am = amenities.isNotEmpty
        ? 'Has: ${amenities.take(3).join(', ')}'
        : 'Basic facilities';
    return '$suit • $am';
  }

  String _templateRunSheet({
    required String purpose,
    required String venue,
    required String date,
    required String timeFrom,
    required String timeTo,
    required String expectedStrength,
  }) => '''
═══════════════════════════════════════
       EVENT RUN SHEET
       MANAV RACHNA UNIVERSITY
═══════════════════════════════════════
Event  : $purpose
Venue  : $venue
Date   : $date
Time   : $timeFrom — $timeTo
Crowd  : $expectedStrength attendees
───────────────────────────────────────
$timeFrom  │ Gates Open / Registration
           │ Welcome desk setup
+15 min    │ AV & microphone check
+30 min    │ Welcome Address
+45 min    │ Main Event — $purpose
+90 min    │ Break / Refreshments
+105 min   │ Event Resumes
-30 min    │ Vote of Thanks
$timeTo    │ Event Ends / Venue Clearance
───────────────────────────────────────
Contact: +91-8800734239 | Extn. 8217
═══════════════════════════════════════
''';
}