import 'package:flutter/foundation.dart';
import '../main.dart';
import 'clash_detection_service.dart';
import 'email_service.dart';

class AutoApprovalService {
  final _clashService = ClashDetectionService();
  final _emailService = EmailService();

  static bool _isSelected(Map<String, dynamic> facilities, String key) {
    final val = facilities[key];
    if (val == null)  return false;
    if (val is bool)  return val;
    if (val is Map) {
      final s = val['selected'];
      if (s is bool)   return s;
      if (s is String) return s.toLowerCase() == 'true';
    }
    return false;
  }

  Future<Map<String, dynamic>> processRequisition({
    required Map<String, dynamic> requisition,
    required String userEmail,
    required String userName,
  }) async {
    final id       = requisition['id']             as String? ?? '';
    final venue    = requisition['venue']           as String? ?? '';
    final purpose  = requisition['purpose']         as String? ?? '';
    final date     = requisition['booking_date']    as String? ?? '';
    final timeFrom = requisition['event_time_from'] as String? ?? '';
    final timeTo   = requisition['event_time_to']   as String? ?? '';

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚀 Processing ID: $id');

    if (id.isEmpty) {
      debugPrint('❌ Empty ID — aborting');
      return {'hasClash': false, 'clashes': [], 'approved': false, 'reason': 'Empty ID'};
    }

    final rawFac     = requisition['facilities'];
    final facilities = rawFac is Map<String, dynamic>
        ? rawFac
        : <String, dynamic>{};

    // ── Step 1: Facility email ─────────────────────────────────────────────
    final photography = _isSelected(facilities, 'photography');
    final videography = _isSelected(facilities, 'videography');
    debugPrint('📸 Photography: $photography | 🎥 Videography: $videography');

    if (photography || videography) {
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
    }

    // ── Step 2: Clash Detection ────────────────────────────────────────────
    debugPrint('🔍 Checking clashes...');
    final clashes = await _clashService.checkClashes(requisition);
    debugPrint('🔍 Clashes found: ${clashes.length}');

    if (clashes.isNotEmpty) {
      await _clashService.saveClashDetails(id, clashes);

      // Send clash email to student
      try {
        await _emailService.sendClashEmail(
          toEmail:   userEmail,
          userName:  userName,
          eventName: purpose,
          eventDate: date,
          eventTime: '$timeFrom → $timeTo',
          venue:     venue,
          clashes:   clashes.map((c) => c.toMap()).toList(),
        );
      } catch (e) {
        debugPrint('⚠️ Clash email error: $e');
      }

      return {
        'hasClash': true,
        'clashes':  clashes,
        'approved': false,
        'reason':   '⚠️ Clash detected',
      };
    }

    // ── Step 3: Auto-Approve ───────────────────────────────────────────────
    debugPrint('✅ No clash — updating status to approved...');

    try {
      // Verify record exists first
      final existing = await supabase
          .from('requisitions')
          .select('id, status')
          .eq('id', id)
          .maybeSingle();

      debugPrint('📋 Current record: $existing');

      if (existing == null) {
        debugPrint('❌ Record not found for ID: $id');
        return {'hasClash': false, 'clashes': [], 'approved': false, 'reason': 'Not found'};
      }

      // Update status
      final result = await supabase
          .from('requisitions')
          .update({
            'status':         'approved',
            'ai_approved':    true,
            'ai_score':       50,
            'ai_reason':      '🤖 Auto-approved — no clash detected.',
            'clash_detected': false,
            'clash_details':  [],
          })
          .eq('id', id)
          .select('id, status'); // ← verify update

      debugPrint('📋 Update result: $result');

      if (result.isNotEmpty && result[0]['status'] == 'approved') {
        debugPrint('✅ Status updated to approved in DB');
      } else {
        debugPrint('❌ Update failed — check RLS in Supabase!');
        debugPrint('👉 Run: ALTER TABLE requisitions DISABLE ROW LEVEL SECURITY;');
      }
    } catch (e) {
      debugPrint('❌ Update error: $e');
      return {'hasClash': false, 'clashes': [], 'approved': false, 'reason': 'Error: $e'};
    }

    // ── Step 4: Approval email to student ─────────────────────────────────
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

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return {
      'hasClash': false,
      'clashes':  [],
      'approved': true,
      'score':    50,
      'reason':   '🤖 Auto-approved — no clash detected.',
    };
  }
}