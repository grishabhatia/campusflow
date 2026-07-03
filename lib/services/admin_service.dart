import '../main.dart';

class AdminService {
  // ─── Fetch all events with room + organizer info ───────────────────────
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    final response = await supabase
        .from('events')
        .select('*, rooms(room_name, room_number, building, floor, capacity), users(name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Fetch only pending events ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    final response = await supabase
        .from('events')
        .select('*, rooms(room_name, room_number, building, floor, capacity), users(name, email)')
        .eq('status', 'pending')
        .order('event_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Fetch approved events ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getApprovedEvents() async {
    final response = await supabase
        .from('events')
        .select('*, rooms(room_name, room_number, building, floor, capacity), users(name, email)')
        .eq('status', 'approved')
        .order('event_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Stats ─────────────────────────────────────────────────────────────
  Future<Map<String, int>> getStats() async {
    final all = await supabase.from('events').select('status');
    final allList = List<Map<String, dynamic>>.from(all);

    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayEvents = await supabase
        .from('events')
        .select('id')
        .eq('event_date', today)
        .eq('status', 'approved');

    int pending = 0, approved = 0, rejected = 0;
    for (final e in allList) {
      switch (e['status']) {
        case 'pending': pending++; break;
        case 'approved': approved++; break;
        case 'rejected': rejected++; break;
      }
    }

    return {
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
      'today': (todayEvents as List).length,
    };
  }

  // ─── Approve event ─────────────────────────────────────────────────────
  Future<void> approveEvent(String eventId) async {
    await supabase
        .from('events')
        .update({'status': 'approved'})
        .eq('id', eventId);
  }

  // ─── Reject event ──────────────────────────────────────────────────────
  Future<void> rejectEvent(String eventId, {String reason = ''}) async {
    await supabase
        .from('events')
        .update({
          'status': 'rejected',
          if (reason.isNotEmpty) 'special_instructions': 'REJECTED: $reason',
        })
        .eq('id', eventId);
  }

  // ─── AI Clash Detection ────────────────────────────────────────────────
  // Returns list of clashing approved events for a given pending event
  Future<List<Map<String, dynamic>>> detectClashes(
    Map<String, dynamic> pendingEvent,
  ) async {
    final roomId = pendingEvent['room_id'];
    final eventDate = pendingEvent['event_date'];
    final newStart = pendingEvent['start_time'] as int;
    final newEnd = pendingEvent['end_time'] as int;
    final pendingId = pendingEvent['id'];

    // Fetch all approved events on the same date & room
    final response = await supabase
        .from('events')
        .select('*, rooms(room_name)')
        .eq('room_id', roomId)
        .eq('event_date', eventDate)
        .eq('status', 'approved')
        .neq('id', pendingId);

    final candidates = List<Map<String, dynamic>>.from(response);

    // Apply overlap formula: newStart < existEnd AND newEnd > existStart
    final clashes = candidates.where((e) {
      final existStart = e['start_time'] as int;
      final existEnd = e['end_time'] as int;
      return newStart < existEnd && newEnd > existStart;
    }).toList();

    return clashes;
  }

  // Helper: convert minutes to readable time string
  static String minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }
}
