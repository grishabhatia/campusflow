import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
 static const _serviceId     = 'service_lutnymb';
static const _templateId    = 'template_gu3h19k';
static const _publicKey     = 'krVk8P4Wp03tLhl1R';
  static const _facilityEmail = '0003vaishnavi@gmail.com';

  // ── Core send method ──────────────────────────────────────────────────────
  Future<bool> _send({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    debugPrint('📧 Sending → $toEmail | $subject');

    try {
      final res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_email': toEmail,
            'subject':  subject,
            'message':  body,
          },
        }),
      );

      debugPrint('📧 EmailJS: ${res.statusCode}');

      if (res.statusCode == 200) {
        debugPrint('✅ Email sent to $toEmail');
        return true;
      }

      await _queue(toEmail: toEmail, subject: subject, body: body);
      return true;
    } catch (e) {
      debugPrint('❌ Error: $e');
      await _queue(toEmail: toEmail, subject: subject, body: body);
      return false;
    }
  }

  // ── Queue email in Supabase ──────────────────────────────────────────────
  Future<void> _queue({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    try {
      // ✅ Direct Supabase client — no global variable
      await Supabase.instance.client.from('email_queue').insert({
        'to_email':   toEmail,
        'subject':    subject,
        'body':       body,
        'sent':       false,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Queued: $toEmail');
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
    final facility = [
      if (photography) 'Still Photography',
      if (videography) 'Videography',
    ].join(' & ');

    await _send(
      toEmail: _facilityEmail,
      subject: '📸 $facility Request — $eventName',
      body: '''
Hello Facilities Team,

A new event requires $facility arrangements.

Event    : $eventName
Date     : $eventDate
Time     : $eventTime
Venue    : $venue, Manav Rachna 
Facility : $facility

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
    await _send(
      toEmail: toEmail,
      subject: '🎉 Your Event Request has been Approved!',
      body: '''
Dear $userName,

Your event request has been approved!

Event : $eventName
Date  : $eventDate
Time  : $eventTime
Venue : $venue, Manav Rachna University

Contact : +91-8800734239 | Extn. 8217
Email   : manager.admin@mrvpl.in

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

Event  : $eventName
Venue  : $venue
${reason.isNotEmpty ? 'Reason : $reason' : ''}

Submit a new request with different time/venue.

Contact : +91-8800734239 | Extn. 8217
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
    // To Student
    await _send(
      toEmail: studentEmail,
      subject: '❌ Your Event has been Cancelled',
      body: '''
Dear $userName,

Your event has been cancelled successfully.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 Event : $eventName
📅 Date  : $eventDate
🕐 Time  : $eventTime
📍 Venue : $venue
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If this was a mistake, please contact the admin office.

Contact : +91-8800734239 | Extn. 8217
Email   : manager.admin@mrvpl.in

Thank you,
CampusFlow AI Team
''',
    );

    // To Facilities Team
    final facility = [
      if (photography) 'Still Photography',
      if (videography) 'Videography',
    ].join(' & ');

    await _send(
      toEmail: _facilityEmail,
      subject: '❌ Event Cancelled — $eventName',
      body: '''
Hello,

The following event has been CANCELLED.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EVENT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Event    : $eventName
Date     : $eventDate
Time     : $eventTime
Venue    : $venue
Facility : ${facility.isNotEmpty ? facility : 'None'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Please note: The facilities are no longer required for this event.

CampusFlow AI — Manav Rachna University
Contact: +91-8800734239 | Extn. 8217
''',
    );
  }

  // ── EMAIL 5: Clash Detection Email ──────────────────────────────────────
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
    for (var i = 0; i < clashes.length; i++) {
      final clash = clashes[i];
      clashDetails += '''
${i + 1}. ${clash['clashingEventName'] ?? clash['event_name'] ?? 'Untitled'}
   🕐 ${clash['fromTime'] ?? clash['from_time'] ?? 'N/A'} - ${clash['toTime'] ?? clash['to_time'] ?? 'N/A'}
   👤 ${clash['organizerName'] ?? 'Unknown'}

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

CLASHES FOUND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$clashDetails
💡 Please choose another date, time, or venue.

For assistance, please contact:
📞 +91-8800734239 | Extn. 8217
📧 manager.admin@mrvpl.in

Thank you,
CampusFlow AI Team
''',
    );
  }
}