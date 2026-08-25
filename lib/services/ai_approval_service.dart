import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AIApprovalService {
  final supabase = Supabase.instance.client;

  /// Main method to evaluate event and auto-approve if no clash
  Future<AIApprovalResult> evaluateAndApprove(Map<String, dynamic> eventData) async {
    debugPrint('🔍 AI Approval Service started for event: ${eventData['purpose'] ?? 'Untitled'}');

    try {
      // Step 1: Check for clashes
      final clashResult = await _checkClashes(eventData);

      if (clashResult.hasClash) {
        debugPrint('⚠️ Clash detected! Event will remain pending.');
        
        // Update event with clash info
        await supabase
            .from('requisitions')
            .update({
              'clash_detected': true,
              'clash_details': clashResult.clashes,
              'status': 'pending',
              'ai_approved': false,
              'ai_reason': 'Clash detected with existing event(s)',
            })
            .eq('id', eventData['id']);

        return AIApprovalResult(
          approved: false,
          clashDetected: true,
          clashes: clashResult.clashes,
          message: '⚠️ Clash detected! Your event clashes with another event on the same date/time/venue.',
        );
      }

      // Step 2: No clash → Auto-Approve
      debugPrint('✅ No clash detected! Auto-approving event.');
      
      // Calculate AI score
      final score = await _calculateScore(eventData);
      
      await supabase
          .from('requisitions')
          .update({
            'status': 'approved',
            'ai_approved': true,
            'ai_score': score,
            'ai_reason': 'Auto-approved by AI - No clashes found',
            'clash_detected': false,
            'clash_details': [],
          })
          .eq('id', eventData['id']);

      return AIApprovalResult(
        approved: true,
        clashDetected: false,
        clashes: [],
        message: '✅ Your event has been auto-approved by AI!',
        score: score,
      );

    } catch (e) {
      debugPrint('❌ AI Approval error: $e');
      return AIApprovalResult(
        approved: false,
        clashDetected: false,
        clashes: [],
        message: 'Error in AI approval: $e',
      );
    }
  }

  /// Check if event clashes with any approved event
  Future<ClashResult> _checkClashes(Map<String, dynamic> newEvent) async {
    try {
      final clashes = <Map<String, dynamic>>[];

      // Fetch all approved events on the same date
      final approvedEvents = await supabase
          .from('requisitions')
          .select('*')
          .eq('booking_date', newEvent['booking_date'])
          .eq('status', 'approved');

      for (final existing in approvedEvents) {
        // Skip if it's the same event
        if (existing['id'] == newEvent['id']) continue;

        // Check if same venue
        if (existing['venue'] != newEvent['venue']) continue;

        // Check if time overlaps
        final newStart = _timeToMinutes(newEvent['event_time_from'] ?? '00:00');
        final newEnd = _timeToMinutes(newEvent['event_time_to'] ?? '00:00');
        final existingStart = _timeToMinutes(existing['event_time_from'] ?? '00:00');
        final existingEnd = _timeToMinutes(existing['event_time_to'] ?? '00:00');

        if (newStart < existingEnd && newEnd > existingStart) {
          // Get user name
          String userName = 'Unknown';
          try {
            final userData = await supabase
                .from('users')
                .select('name')
                .eq('id', existing['user_id'])
                .single();
            userName = userData['name'] ?? 'Unknown';
          } catch (_) {}

          clashes.add({
            'event_id': existing['id'],
            'event_name': existing['purpose'] ?? 'Untitled',
            'user_name': userName,
            'event_time_from': existing['event_time_from'],
            'event_time_to': existing['event_time_to'],
          });
        }
      }

      return ClashResult(
        hasClash: clashes.isNotEmpty,
        clashes: clashes,
      );

    } catch (e) {
      debugPrint('❌ Clash detection error: $e');
      return ClashResult(hasClash: false, clashes: []);
    }
  }

  /// Calculate AI score based on past patterns
  Future<int> _calculateScore(Map<String, dynamic> event) async {
    try {
      // Fetch past approved events from same venue
      final pastEvents = await supabase
          .from('requisitions')
          .select('*')
          .eq('venue', event['venue'])
          .eq('status', 'approved')
          .limit(10);

      if (pastEvents.isEmpty) return 80; // Default good score

      int score = 50; // Base score

      // Same venue boost
      score += 20;

      // Similar purpose boost
      for (final past in pastEvents) {
        if (_isPurposeSimilar(past['purpose'] ?? '', event['purpose'] ?? '')) {
          score += 10;
          break;
        }
      }

      // Same time pattern boost
      for (final past in pastEvents) {
        if (_isTimeSimilar(past['event_time_from'] ?? '00:00', event['event_time_from'] ?? '00:00')) {
          score += 10;
          break;
        }
      }

      // Cap at 100
      return score > 100 ? 100 : score;

    } catch (e) {
      debugPrint('❌ Score calculation error: $e');
      return 70;
    }
  }

  /// Convert time string to minutes
  int _timeToMinutes(String time) {
    try {
      time = time.trim();
      bool isPM = time.toUpperCase().contains('PM');
      bool isAM = time.toUpperCase().contains('AM');
      time = time.replaceAll(RegExp(r'[APMapm\s]'), '');
      final parts = time.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      if (isPM && h != 12) h += 12;
      if (isAM && h == 12) h = 0;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  /// Check if purposes are similar
  bool _isPurposeSimilar(String purpose1, String purpose2) {
    final words1 = purpose1.toLowerCase().split(RegExp(r'\s+'));
    final words2 = purpose2.toLowerCase().split(RegExp(r'\s+'));
    final common = words1.where((w) => words2.contains(w)).length;
    return common >= 2;
  }

  /// Check if time is within 30 minutes
  bool _isTimeSimilar(String time1, String time2) {
    final t1 = _timeToMinutes(time1);
    final t2 = _timeToMinutes(time2);
    return (t1 - t2).abs() <= 30;
  }

  /// Get clash details for display
  String getClashMessage(List<Map<String, dynamic>> clashes) {
    if (clashes.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('⚠️ Clash Detected!');
    buffer.writeln('Your event clashes with the following event(s):');
    buffer.writeln();
    
    for (var i = 0; i < clashes.length; i++) {
      final clash = clashes[i];
      buffer.writeln('${i + 1}. ${clash['event_name'] ?? 'Untitled'}');
      buffer.writeln('   📅 ${clash['event_time_from']} - ${clash['event_time_to']}');
      buffer.writeln('   👤 ${clash['user_name'] ?? 'Unknown'}');
      buffer.writeln();
    }
    
    buffer.writeln('💡 Please choose another date, time, or venue.');
    
    return buffer.toString();
  }
}

/// AI Approval Result Model
class AIApprovalResult {
  final bool approved;
  final bool clashDetected;
  final List<Map<String, dynamic>> clashes;
  final String message;
  final int? score;

  AIApprovalResult({
    required this.approved,
    required this.clashDetected,
    required this.clashes,
    required this.message,
    this.score,
  });
}

/// Clash Result Model
class ClashResult {
  final bool hasClash;
  final List<Map<String, dynamic>> clashes;

  ClashResult({
    required this.hasClash,
    required this.clashes,
  });
}