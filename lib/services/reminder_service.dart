import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';

class ReminderService {
  final _emailService = EmailService();

  static const _adminEmail = 'grishabhatia62@gmail.com';
  static const _deptEmails = {
    'CSE': '07vaishnavi.official@gmail.com',
    'Civil': 'grishabhatia2@gmail.com',
  };
  static const _registrarEmail = 'v02816754@gmail.com';
  static const _loginLink = 'https://mriirscampusflow.netlify.app/#/login';

  // ✅ 5 minute wait — reminder bhejne se pehle
  static const int _reminderWaitMinutes = 5;

  // ✅ Sirf 1 day ke events check karo
  static const int _maxEventAgeDays = 1;

  // ✅ Sirf 1 reminder per stage (Admin/Dept/Registrar)
  static const int _maxRemindersPerEvent = 1;

  // ✅ FIX: 1 din (1440 min) tak purane events ke liye reminder bhejo
  // 15 min → 1440 min (1 day)
  static const int _reminderExpiryMinutes = 1440;

  Future<void> checkAndSendReminders() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📧 Checking reminders...');

    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: _maxEventAgeDays));

      debugPrint('⏰ Current time: $now');
      debugPrint('📅 Cutoff: $cutoffDate (only last $_maxEventAgeDays days)');

      final response = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .eq('status', 'pending')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: true);

      final events = List<Map<String, dynamic>>.from(response);
      debugPrint('📋 Recent pending events: ${events.length}');

      for (final event in events) {
        await _processEventReminder(event, now);
      }

      debugPrint('✅ Reminder check complete');
    } catch (e) {
      debugPrint('❌ Reminder error: $e');
    }
  }

  Future<void> _processEventReminder(
      Map<String, dynamic> event, DateTime now) async {
    try {
      final createdAt = DateTime.parse(event['created_at']);
      final minutesSince = now.difference(createdAt).inMinutes;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📌 Event: ${event['purpose']}');
      debugPrint('   Created: $createdAt');
      debugPrint('   Minutes since: $minutesSince');

      // ✅ Sirf 1 reminder per event
      final reminderCount = event['reminder_count'] ?? 0;
      if (reminderCount >= _maxRemindersPerEvent) {
        debugPrint('   ⏭️ Reminder already sent — skipping');
        return;
      }

      // ✅ 5 min se pehle skip
      if (minutesSince < _reminderWaitMinutes) {
        debugPrint('   ⏳ Not yet $_reminderWaitMinutes min');
        return;
      }

      // ✅ 1 din (1440 min) se zyada purane skip
      if (minutesSince > _reminderExpiryMinutes) {
        debugPrint('   ⏭️ Event too old ($minutesSince min) — skipping');
        return;
      }

      final adminApproved = event['admin_approved'] == true;
      final deptApproved = event['dept_approved'] == true;
      final registrarApproved = event['registrar_approved'] == true;

      debugPrint('   Admin: $adminApproved | Dept: $deptApproved | Reg: $registrarApproved');

      String toEmail = '';
      String role = '';
      int minutesSinceApproval = 0;

      if (!adminApproved) {
        toEmail = _adminEmail;
        role = 'Admin';
        minutesSinceApproval = minutesSince;
      } else if (!deptApproved) {
        final adminApprovedAt = event['admin_approved_at'];
        if (adminApprovedAt != null) {
          final approvedTime = DateTime.parse(adminApprovedAt);
          minutesSinceApproval = now.difference(approvedTime).inMinutes;

          // ✅ 5 min se pehle skip
          if (minutesSinceApproval < _reminderWaitMinutes) {
            debugPrint('   ⏳ Admin approved $minutesSinceApproval min ago');
            return;
          }
          // ✅ 1 din se zyada purane skip
          if (minutesSinceApproval > _reminderExpiryMinutes) {
            debugPrint('   ⏭️ Admin approval too old — skipping');
            return;
          }
        } else {
          return;
        }

        final dept = event['department'] ?? 'Unknown';
        toEmail = _deptEmails[dept] ?? '';
        role = '$dept Department Head';
      } else if (!registrarApproved) {
        final deptApprovedAt = event['dept_approved_at'];
        if (deptApprovedAt != null) {
          final approvedTime = DateTime.parse(deptApprovedAt);
          minutesSinceApproval = now.difference(approvedTime).inMinutes;

          if (minutesSinceApproval < _reminderWaitMinutes) {
            debugPrint('   ⏳ Dept approved $minutesSinceApproval min ago');
            return;
          }
          if (minutesSinceApproval > _reminderExpiryMinutes) {
            debugPrint('   ⏭️ Dept approval too old — skipping');
            return;
          }
        } else {
          return;
        }

        toEmail = _registrarEmail;
        role = 'Registrar';
      } else {
        debugPrint('   ✅ All approved — skipping');
        return;
      }

      if (toEmail.isEmpty) {
        debugPrint('   ❌ No email for role: $role');
        return;
      }

      debugPrint('   📧 Sending reminder to $toEmail ($role)');

      final sent = await _emailService.sendReminderEmail(
        toEmail: toEmail,
        recipientRole: role,
        eventName: event['purpose'] ?? 'Untitled',
        eventDate: event['booking_date'] ?? 'N/A',
        eventTime:
            '${event['event_time_from'] ?? ''} → ${event['event_time_to'] ?? ''}',
        venue: event['venue'] ?? 'N/A',
        department: event['department'] ?? 'N/A',
        requestedBy: event['user_email'] ?? 'N/A',
        hoursSince: minutesSinceApproval,
        loginLink: _loginLink,
      );

      if (sent) {
        await Supabase.instance.client
            .from('requisitions')
            .update({
              'last_reminder_sent_at': now.toIso8601String(),
              'reminder_count': (event['reminder_count'] ?? 0) + 1,
            })
            .eq('id', event['id']);

        debugPrint('   ✅ Reminder sent to $toEmail');
      } else {
        debugPrint('   ❌ Reminder FAILED to $toEmail');
      }
    } catch (e) {
      debugPrint('   ❌ Process error: $e');
    }
  }
}