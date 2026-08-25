import 'package:flutter/foundation.dart';
import '../main.dart';
import 'clash_detection_service.dart';
import 'email_service.dart';

class AutoApprovalService {
  final _clashService = ClashDetectionService();
  final _emailService = EmailService();

  /// Safely read a facility boolean.
  /// Handles both flat (true) and nested ({'selected': true}) formats.
  static bool _isSelected(Map<String, dynamic> facilities, String key) {
    final val = facilities[key];
    if (val == null)    return false;
    if (val is bool)    return val;
    if (val is Map) {
      final s = val['selected'];
      if (s is bool)   return s;
      if (s is String) return s.toLowerCase() == 'true';
    }
    return false;
  }

  /// Full flow after student submits:
  /// 1. Photography/Videography → email to facility team
  /// 2. Clash detection
  /// 3. No clash → auto-approve + email to student
  Future<Map<String, dynamic>> processRequisition({
    required Map<String, dynamic> requisition,
    required String userEmail,
    required String userName,
  }) async {
    final id       = requisition['id']             as String;
    final venue    = requisition['venue']           as String? ?? '';
    final purpose  = requisition['purpose']         as String? ?? '';
    final date     = requisition['booking_date']    as String? ?? '';
    final timeFrom = requisition['event_time_from'] as String? ?? '';
    final timeTo   = requisition['event_time_to']   as String? ?? '';

    final rawFac     = requisition['facilities'];
    final facilities = rawFac is Map<String, dynamic>
        ? rawFac
        : <String, dynamic>{};

    debugPrint('────────────────────────────────────');
    debugPrint('📦 Full facilities: $facilities');

    // ── Step 1: Facility email ─────────────────────────────────────────────
    final photography = _isSelected(facilities, 'photography');
    final videography = _isSelected(facilities, 'videography');

    debugPrint('📸 Photography: $photography  |  🎥 Videography: $videography');

    if (photography || videography) {
      debugPrint('📧 Sending facility email to 0003vaishnavi@gmail.com...');
      try {
        await _emailService.sendFacilityEmail(
          eventName:   purpose,
          eventDate:   date,
          eventTime:   '$timeFrom → $timeTo',
          venue:       venue,
          photography: photography,
          videography: videography,
          userName:    userName,
          userEmail:   userEmail,
        );
        debugPrint('✅ Facility email sent');
      } catch (e) {
        debugPrint('⚠️ Facility email error: $e');
      }
    } else {
      debugPrint('ℹ️ No photography/videography — skipping facility email');
    }

    // ── Step 2: Clash detection ────────────────────────────────────────────
    debugPrint('🔍 Running clash detection...');
    final clashes = await _clashService.checkClashes(requisition);
    debugPrint('🔍 Clashes found: ${clashes.length}');

    if (clashes.isNotEmpty) {
      await _clashService.saveClashDetails(id, clashes);
      debugPrint('⚠️ Clash detected — status stays pending');
      return {
        'hasClash': true,
        'clashes':  clashes,
        'approved': false,
        'reason':   '⚠️ Clash detected with an existing approved event.',
      };
    }

    // ── Step 3: Auto-approve ───────────────────────────────────────────────
    debugPrint('✅ No clash — auto-approving...');
    final scoreResult = await _score(requisition);
    final score       = scoreResult['score'] as int;
    final reason      = scoreResult['reason'] as String;

    await supabase.from('requisitions').update({
      'status':         'approved',
      'ai_approved':    true,
      'ai_score':       score,
      'ai_reason':      reason,
      'clash_detected': false,
      'clash_details':  [],
    }).eq('id', id);

    debugPrint('✅ Auto-approved! Score: $score');

    // ── Step 4: Approval email → student ──────────────────────────────────
    debugPrint('📧 Sending approval email to $userEmail...');
    try {
      await _emailService.sendApprovalEmail(
        toEmail:   userEmail,
        userName:  userName,
        eventName: purpose,
        eventDate: date,
        eventTime: '$timeFrom → $timeTo',
        venue:     venue,
      );
      debugPrint('✅ Approval email sent to $userEmail');
    } catch (e) {
      debugPrint('⚠️ Approval email error: $e');
    }

    debugPrint('────────────────────────────────────');

    return {
      'hasClash': false,
      'clashes':  [],
      'approved': true,
      'score':    score,
      'reason':   reason,
    };
  }

  // ── Scoring ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _score(Map<String, dynamic> req) async {
    try {
      final history = List<Map<String, dynamic>>.from(
        await supabase
            .from('requisitions')
            .select('venue, purpose')
            .eq('status', 'approved')
            .neq('id', req['id'] ?? '')
            .limit(50),
      );

      if (history.isEmpty) {
        return {
          'score':  60,
          'reason': '🤖 Auto-approved by AI (first booking at this venue).',
        };
      }

      int score = 30;
      final reasons = <String>[];

      for (final past in history) {
        if ((past['venue'] ?? '') == (req['venue'] ?? '')) {
          score += 10;
          reasons.add('Venue approved before');
          break;
        }
      }
      for (final past in history) {
        if (_keywordMatch(past['purpose'] ?? '', req['purpose'] ?? '')) {
          score += 10;
          reasons.add('Similar event approved before');
          break;
        }
      }

      return {
        'score':  score.clamp(0, 100),
        'reason': '🤖 Auto-approved by AI (Score: ${score.clamp(0, 100)}/100). '
            '${reasons.isNotEmpty ? reasons.join(', ') + '.' : 'No clash detected.'}',
      };
    } catch (_) {
      return {
        'score':  50,
        'reason': '🤖 Auto-approved by AI (no clash detected).',
      };
    }
  }

  bool _keywordMatch(String a, String b) {
    final wa = a.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
    final wb = b.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();
    return wa.intersection(wb).isNotEmpty;
  }
}