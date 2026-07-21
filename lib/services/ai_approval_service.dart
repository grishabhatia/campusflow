import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

class AIApprovalService {
  final supabase = Supabase.instance.client;
  final GeminiService? _geminiService;

  AIApprovalService({String? geminiApiKey})
      : _geminiService = geminiApiKey != null ? GeminiService(geminiApiKey) : null;

  /// Evaluate event and return approval decision
  Future<AiDecision> evaluate(Map<String, dynamic> event) async {
    debugPrint('🔍 Evaluating event: ${event['event_name']}');

    // 1. Fetch past approved events
    final approvedEvents = await supabase
        .from('events')
        .select('*')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(20);

    debugPrint('📊 Found ${approvedEvents.length} past approved events');

    // 2. If no past events → use Gemini or manual review
    if (approvedEvents.isEmpty) {
      if (_geminiService != null) {
        try {
          final prompt = '''
Should this event be approved?
Event: ${event['purpose'] ?? 'N/A'}
Date: ${event['event_date'] ?? 'N/A'}
Time: ${event['start_time'] ?? 'N/A'} - ${event['end_time'] ?? 'N/A'}
Room: ${event['room_id'] ?? 'N/A'}
Organization: ${event['organization'] ?? 'N/A'}

Return only one word: 'approve' or 'manual'.
''';
          final response = await _geminiService!.generateContent(prompt);
          final decision = response.trim().toLowerCase();

          if (decision == 'approve') {
            return AiDecision(
              autoApproved: true,
              score: 85,
              reason: 'AI approved via Gemini',
            );
          }
        } catch (e) {
          debugPrint('Gemini error: $e');
        }
      }

      return AiDecision(
        autoApproved: false,
        score: 0,
        reason: 'No past events to compare with. Manual review required.',
      );
    }

    // 3. Calculate score based on past patterns
    int bestScore = 0;
    String bestReason = '';

    for (final pastEvent in approvedEvents) {
      int score = 0;
      List<String> matches = [];

      // Same room (20 points)
      if (pastEvent['room_id'] == event['room_id']) {
        score += 20;
        matches.add('same room');
      }

      // Similar purpose (10 points)
      if (_isPurposeSimilar(pastEvent['purpose'] ?? '', event['purpose'] ?? '')) {
        score += 10;
        matches.add('similar purpose');
      }

      // Same organization (20 points)
      if (pastEvent['organization'] == event['organization']) {
        score += 20;
        matches.add('same organization');
      }

      // Time within 1 hour (10 points)
      if (_isTimeWithinOneHour(pastEvent, event)) {
        score += 10;
        matches.add('time pattern matches');
      }

      if (score > bestScore) {
        bestScore = score;
        bestReason = 'Matched: ${matches.join(', ')}';
      }
    }

    // 🔥 FORCE AUTO-APPROVE FOR TESTING (score >= 0)
    // Change back to 50 for production
    final bool autoApprove = bestScore >= 0;

    debugPrint('✅ Score: $bestScore, Auto-Approve: $autoApprove');
    debugPrint('📝 Reason: $bestReason');

    return AiDecision(
      autoApproved: autoApprove,
      score: bestScore,
      reason: autoApprove
          ? '✅ Auto-approved by AI: $bestReason (Score: $bestScore)'
          : 'Manual review needed: score $bestScore < 50',
    );
  }

  /// Save decision to database
  Future<void> applyDecision(String eventId, AiDecision decision) async {
    final status = decision.autoApproved ? 'approved' : 'pending';

    debugPrint('💾 Saving decision: status=$status, ai_approved=${decision.autoApproved}');
    debugPrint('💾 Score: ${decision.score}, Reason: ${decision.reason}');

    try {
      await supabase.from('events').update({
        'status': status,
        'ai_approved': decision.autoApproved,
        'ai_score': decision.score,
        'ai_reason': decision.reason,
      }).eq('id', eventId);

      debugPrint('✅ Decision saved successfully!');
    } catch (e) {
      debugPrint('❌ Error saving decision: $e');
      rethrow;
    }
  }

  /// Check if purposes are similar (keyword matching)
  bool _isPurposeSimilar(String purpose1, String purpose2) {
    final words1 = purpose1.toLowerCase().split(RegExp(r'\s+'));
    final words2 = purpose2.toLowerCase().split(RegExp(r'\s+'));
    final common = words1.where((w) => words2.contains(w)).length;
    return common >= 2;
  }

  /// Check if time is within 1 hour
  bool _isTimeWithinOneHour(Map<String, dynamic> past, Map<String, dynamic> current) {
    try {
      final pastStart = DateTime.parse(past['event_date']).add(
        Duration(minutes: past['start_time'] ?? 0),
      );
      final currentStart = DateTime.parse(current['event_date']).add(
        Duration(minutes: current['start_time'] ?? 0),
      );
      return pastStart.difference(currentStart).abs().inMinutes <= 60;
    } catch (_) {
      return false;
    }
  }
}

/// AI Decision Model
class AiDecision {
  final bool autoApproved;
  final int score;
  final String reason;

  AiDecision({
    required this.autoApproved,
    required this.score,
    required this.reason,
  });
}