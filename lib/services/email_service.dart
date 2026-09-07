import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  // ✅ SERVICE ID CHECK KARO — EmailJS Dashboard mein konsi service use kar rahe ho?
  static const _serviceId     = 'service_68vde1j';  // ← YE CHANGE KARO AGAR service_lutnymb HAI TOH
  static const _templateId    = 'template_gu3h19k';
  static const _publicKey     = 'krVk8P4Wp03tLhl1R';
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
    debugPrint('📧 BODY: $body');

    try {
      final payload = jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': toEmail,
          'subject': subject,
          'message': body,
          'name': toEmail.split('@')[0],  // ✅ Added for template
          'time': DateTime.now().toString(),  // ✅ Added for template
        },
      });

      debugPrint('📧 Payload: $payload');

      final res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost:3000',  // ✅ CORS fix
        },
        body: payload,
      );

      debugPrint('📧 Status: ${res.statusCode}');
      debugPrint('📧 Response: ${res.body}');

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
      debugPrint('✅ Queued email for $toEmail');
    } catch (e) {
      debugPrint('❌ Queue error: $e');
    }
  }

  // ── EMAIL 1: Facility Email ──────────────────────────────────────────────
  Future<void> sendFacilityEmail({
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
    required bool photography,
    required bool videography,
    required String userName,
    required String userEmail,
  }) async {
    debugPrint('📸 sendFacilityEmail called');
    debugPrint('   photography=$photography videography=$videography');

    final facility = [
      if (photography) 'Still Photography',
      if (videography) 'Videography',
    ].join(' & ');

    await _send(
      toEmail: _facilityEmail,
      subject: '📸 Facility Request: $facility — $eventName',
      body: '''
Hello Facilities Team,

A new event requires $facility arrangements.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Event    : $eventName
Date     : $eventDate
Time     : $eventTime
Venue    : $venue, Manav Rachna University
Facility : $facility
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Requested By : $userName ($userEmail)

Please arrange 48 hours prior to the event.

CampusFlow AI — +91-8800734239 | Extn. 8217
''',
    );
  }

  // ── EMAIL 2: Approval Email ──────────────────────────────────────────────
  Future<void> sendApprovalEmail({
    required String toEmail,
    required String userName,
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
  }) async {
    debugPrint('✅ sendApprovalEmail called → $toEmail');

    await _send(
      toEmail: toEmail,
      subject: '🎉 Your Event Request has been Approved!',
      body: '''
Dear $userName,

Your event request has been approved! 🎉

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Event : $eventName
Date  : $eventDate
Time  : $eventTime
Venue : $venue, Manav Rachna University
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For assistance, please contact:
📞 +91-8800734239 | Extn. 8217
📧 manager.admin@mrvpl.in

CampusFlow Smart Team
Manav Rachna International Institute of Research and Studies
''',
    );
  }

  // ── EMAIL 3: Rejection Email ─────────────────────────────────────────────
  Future<void> sendRejectionEmail({
    required String toEmail,
    required String userName,
    required String eventName,
    required String venue,
    required String reason,
  }) async {
    await _send(
      toEmail: toEmail,
      subject: '❌ Update on Your Event Request — $eventName',
      body: '''
Dear $userName,

Your event request was not approved.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Event  : $eventName
Venue  : $venue
${reason.isNotEmpty ? 'Reason : $reason' : ''}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Please submit a new request with a different time or venue.

📞 +91-8800734239 | Extn. 8217
📧 manager.admin@mrvpl.in

CampusFlow AI Team
''',
    );
  }

  // ── EMAIL 4: Cancellation Email ──────────────────────────────────────────
  Future<void> sendCancellationEmail({
    required String studentEmail,
    required String userName,
    required String eventName,
    required String eventDate,
    required String eventTime,
    required String venue,
    required bool photography,
    required bool videography,
  }) async {
    // To student
    await _send(
      toEmail: studentEmail,
      subject: '❌ Your Event has been Cancelled — $eventName',
      body: '''
Dear $userName,

Your event has been cancelled.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Event : $eventName
Date  : $eventDate
Time  : $eventTime
Venue : $venue
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If this was a mistake, please contact the admin office.

📞 +91-8800734239 | Extn. 8217
📧 manager.admin@mrvpl.in

CampusFlow AI Team
''',
    );

    // To facility team
    final facility = [
      if (photography) 'Still Photography',
      if (videography) 'Videography',
    ].join(' & ');

    if (facility.isNotEmpty) {
      await _send(
        toEmail: _facilityEmail,
        subject: '❌ Event Cancelled — $eventName',
        body: '''
Hello Facilities Team,

The following event has been CANCELLED.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Event    : $eventName
Date     : $eventDate
Time     : $eventTime
Venue    : $venue
Facility : $facility
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Facilities are no longer required.

CampusFlow AI — Manav Rachna University
📞 +91-8800734239 | Extn. 8217
''',
      );
    }
  }

  // ── EMAIL 5: Clash Email ─────────────────────────────────────────────────
  Future<void> sendClashEmail({
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
${i + 1}. ${c['event_name'] ?? c['clashingEventName'] ?? 'Untitled Event'}
   🕐 ${c['time_from'] ?? c['fromTime'] ?? 'N/A'} → ${c['time_to'] ?? c['toTime'] ?? 'N/A'}
   👤 ${c['organizerName'] ?? 'Unknown'}

''';
    }

    await _send(
      toEmail: toEmail,
      subject: '⚠️ Clash Detected in Your Event Request',
      body: '''
Dear $userName,

Your event request has a clash with another approved event.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
YOUR EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 Event : $eventName
📅 Date  : $eventDate
🕐 Time  : $eventTime
📍 Venue : $venue

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CLASHES FOUND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$clashDetails
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 Please choose another date, time, or venue.

For assistance:
📞 +91-8800734239 | Extn. 8217
📧 manager.admin@mrvpl.in

CampusFlow AI Team
''',
    );
  }
}