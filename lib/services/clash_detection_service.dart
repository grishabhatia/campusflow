import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';  // ✅ Add this for debugPrint

class ClashDetectionService {
  final supabase = Supabase.instance.client;

  /// Check if event clashes with any approved event
  Future<ClashResult> checkClash(Map<String, dynamic> newEvent) async {
    try {
      final clashes = <Map<String, dynamic>>[];

      // Fetch all approved events on the same date
      final approvedEvents = await supabase
          .from('events')
          .select('*, rooms(*)')
          .eq('event_date', newEvent['event_date'])
          .eq('status', 'approved');

      for (final existing in approvedEvents) {
        // Skip if it's the same event
        if (existing['id'] == newEvent['id']) continue;

        final newStart = newEvent['start_time'] as int;
        final newEnd = newEvent['end_time'] as int;
        final existingStart = existing['start_time'] as int;
        final existingEnd = existing['end_time'] as int;

        // Check if same room and time overlaps
        if (newEvent['room_id'] == existing['room_id'] &&
            newStart < existingEnd &&
            newEnd > existingStart) {
          clashes.add({
            'event_id': existing['id'],
            'event_name': existing['event_name'] ?? 'Untitled',
            'start_time': existingStart,
            'end_time': existingEnd,
            'room_name': existing['rooms']?['room_name'] ?? 'N/A',
          });
        }
      }

      // Update event with clash info
      final hasClash = clashes.isNotEmpty;
      await supabase.from('events').update({
        'clash_detected': hasClash,
        'clash_details': clashes,
      }).eq('id', newEvent['id']);

      return ClashResult(
        hasClash: hasClash,
        clashes: clashes,
      );
    } catch (e) {
      debugPrint('Error checking clash: $e');
      return ClashResult(hasClash: false, clashes: []);
    }
  }

  /// Format time from minutes
  String formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${min.toString().padLeft(2, '0')} $period';
  }

  /// Check clashes and return list (for create_event_screen.dart)
  Future<List<Map<String, dynamic>>> checkClashes(Map<String, dynamic> event) async {
    final result = await checkClash(event);
    return result.clashes;
  }

  /// Save clash details to database
  Future<void> saveClashDetails(String eventId, List<Map<String, dynamic>> clashes) async {
    await supabase
        .from('events')
        .update({
          'clash_detected': clashes.isNotEmpty,
          'clash_details': clashes,
        })
        .eq('id', eventId);
  }
}

class ClashResult {
  final bool hasClash;
  final List<Map<String, dynamic>> clashes;

  ClashResult({required this.hasClash, required this.clashes});
}