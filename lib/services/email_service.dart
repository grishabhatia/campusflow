import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  // 🔑 YOUR EMAILJS CREDENTIALS (NEW)
  static const _serviceId     = 'service_nuz63ki';
  static const _templateId    = 'template_vga9c6u';
  static const _publicKey     = 'GiJo_DIeH0HgE18OX';
  static const _facilityEmail = '0003vaishnavi@gmail.com';

  // ── Core send method ───────────────────────────────────────────────────────
  Future<bool> _send({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📧 TO: $toEmail');
    debugPrint('📧 SUBJECT: $subject');

    try {
      final payload = jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': toEmail,
          'subject': subject,
          'message': body,
          'name': toEmail.split('@')[0],
          'time': DateTime.now().toString(),
        },
      });

      final res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost:3000',
        },
        body: payload,
      );

      debugPrint('📧 Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        debugPrint('✅ Email SENT to $toEmail');
        return true;
      } else {
        debugPrint('❌ EmailJS failed: ${res.statusCode} — ${res.body}');
        await _queue(toEmail: toEmail, subject: subject, body: body);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Email error: $e');
      await _queue(toEmail: toEmail, subject: subject, body: body);
      return false;
    }
  }

  // ── Queue in Supabase ──────────────────────────────────────────────────────
  Future<void> _queue({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    try {
      await Supabase.instance.client.from('email_queue').insert({
        'to_email': toEmail,
        'subject': subject,
        'body': body,
        'sent': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Queue error: $e');
    }
  }

  // ── EMAIL 1: Facility Email ──────────────────────────────────────────────
  Future<bool> sendFacilityEmail({
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
    required bool photography,
    required bool videography,
    required String userName,
    required String userEmail,
  }) async {
    final facility = [
      if (photography) 'Still Photography',
      if (videography) 'Videography',
    ].join(' & ');

    return await _send(
      toEmail: _facilityEmail,
      subject: '📸 Facility Request: $facility — $eventName',
      body: '''
Hello Facilities Team,

A new event requires $facility arrangements.

Event    : $eventName
Date     : $eventDate
Time     : $eventTime
Venue    : $venue
Facility : $facility

Requested By : $userName ($userEmail)

Please arrange 48 hours prior to the event.
''',
    );
  }

  // ── EMAIL 2: Approval Email ──────────────────────────────────────────────
  Future<bool> sendApprovalEmail({
    required String toEmail,
    required String userName,
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
  }) async {
    debugPrint('✅ sendApprovalEmail → $toEmail');

    return await _send(
      toEmail: toEmail,
      subject: '🎉 Your Event Request has been Approved!',
      body: '''
Dear $userName,

Your event request has been approved! 🎉

Event : $eventName
Date  : $eventDate
Time  : $eventTime
Venue : $venue

For assistance:
📞 +91-8800734239 | Extn. 8217
📧 manager.admin@mrvpl.in
''',
    );
  }

  // ── EMAIL 3: Rejection Email ─────────────────────────────────────────────
  Future<bool> sendRejectionEmail({
    required String toEmail,
    required String userName,
    required String eventName,
    required String venue,
    required String reason,
  }) async {
    return await _send(
      toEmail: toEmail,
      subject: '❌ Update on Your Event Request — $eventName',
      body: '''
Dear $userName,

Your event request was not approved.

Event  : $eventName
Venue  : $venue
${reason.isNotEmpty ? 'Reason : $reason' : ''}

Please submit a new request.
''',
    );
  }

  // ── EMAIL 4: Cancellation Email ──────────────────────────────────────────
  Future<bool> sendCancellationEmail({
    required String studentEmail,
    required String userName,
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
    required bool photography,
    required bool videography,
  }) async {
    final studentSent = await _send(
      toEmail: studentEmail,
      subject: '❌ Your Event has been Cancelled — $eventName',
      body: '''
Dear $userName,

Your event has been cancelled.

Event : $eventName
Date  : $eventDate
Time  : $eventTime
Venue : $venue
''',
    );

    final facility = [
      if (photography) 'Still Photography',
      if (videography) 'Videography',
    ].join(' & ');

    if (facility.isNotEmpty) {
      await _send(
        toEmail: _facilityEmail,
        subject: '❌ Event Cancelled — $eventName',
        body: '''
The following event has been CANCELLED.

Event    : $eventName
Date     : $eventDate
Time     : $eventTime
Venue    : $venue
Facility : $facility
''',
      );
    }

    return studentSent;
  }

  // ── EMAIL 5: Clash Email ─────────────────────────────────────────────────
  Future<bool> sendClashEmail({
    required String toEmail,
    required String userName,
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
    required List<Map<String, dynamic>> clashes,
  }) async {
    String clashDetails = '';
    for (int i = 0; i < clashes.length; i++) {
      final c = clashes[i];
      clashDetails += '''
${i + 1}. ${c['event_name'] ?? 'Untitled Event'}
   🕐 ${c['time_from'] ?? 'N/A'} → ${c['time_to'] ?? 'N/A'}
''';
    }

    return await _send(
      toEmail: toEmail,
      subject: '⚠️ Clash Detected in Your Event Request',
      body: '''
Dear $userName,

Your event request has a clash with another approved event.

Event : $eventName
Date  : $eventDate
Time  : $eventTime
Venue : $venue

CLASHES:
$clashDetails

Please choose another date, time, or venue.
''',
    );
  }

  // ── EMAIL 6: Password Reset Email ────────────────────────────────────────
  Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String resetLink,
  }) async {
    return await _send(
      toEmail: toEmail,
      subject: '🔐 Reset Your Password - CampusFlow Smart',
      body: '''
Hello,

We received a request to reset your password.

Click the link below:
$resetLink

This link will expire in 24 hours.
''',
    );
  }

  // ── EMAIL 7: Reminder Email ──────────────────────────────────────────────
  // ✅ FIXED: Return type Future<bool>
  // ✅ FIXED: "Pending Since" line removed
  Future<bool> sendReminderEmail({
    required String toEmail,
    required String recipientRole,
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
    required String department,
    required String requestedBy,
    required int hoursSince,
    required String loginLink,
  }) async {
    debugPrint('📧 sendReminderEmail → $toEmail ($recipientRole)');

    return await _send(
      toEmail: toEmail,
      subject: '⏰ Reminder: Pending Event Approval - $eventName',
      body: '''
Dear $recipientRole,

This is a friendly reminder that an event request is pending your approval.

EVENT DETAILS
Event       : $eventName
Date        : $eventDate
Time        : $eventTime
Venue       : $venue
Department  : $department
Requested By: $requestedBy

Please login to approve or reject this event:
🔗 $loginLink

---
CampusFlow Smart
Manav Rachna University
''',
    );
  }
}