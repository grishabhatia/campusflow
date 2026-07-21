import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ Direct import

class AdminService {
  // ✅ Direct Supabase client
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAllRequisitions() async {
    final response = await supabase
        .from('requisitions')
        .select('*, users(name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getPendingRequisitions() async {
    final response = await supabase
        .from('requisitions')
        .select('*, users(name, email)')
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getApprovedRequisitions() async {
    final response = await supabase
        .from('requisitions')
        .select('*, users(name, email)')
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> getStats() async {
    final all = await supabase.from('requisitions').select('status');
    final allList = List<Map<String, dynamic>>.from(all);

    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayEvents = await supabase
        .from('requisitions')
        .select('id')
        .eq('booking_date', today)
        .eq('status', 'approved');

    int pending = 0, approved = 0, rejected = 0;
    for (final e in allList) {
      switch (e['status']) {
        case 'pending':  pending++;  break;
        case 'approved': approved++; break;
        case 'rejected': rejected++; break;
      }
    }

    return {
      'pending':  pending,
      'approved': approved,
      'rejected': rejected,
      'today':    (todayEvents as List).length,
    };
  }

  Future<void> approveRequisition(String id) async {
    await supabase
        .from('requisitions')
        .update({'status': 'approved'})
        .eq('id', id);
  }

  Future<void> rejectRequisition(String id, {String reason = ''}) async {
    await supabase
        .from('requisitions')
        .update({
          'status': 'rejected',
          if (reason.isNotEmpty) 'extra_furniture': 'REJECTED: $reason',
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> detectClashes(
    Map<String, dynamic> pendingReq,
  ) async {
    final venue = pendingReq['venue'];
    final pendingId = pendingReq['id'];
    final pendingSlots =
        List<Map<String, dynamic>>.from(pendingReq['slots'] ?? []);

    final response = await supabase
        .from('requisitions')
        .select('*')
        .eq('venue', venue)
        .eq('status', 'approved')
        .neq('id', pendingId);

    final approved = List<Map<String, dynamic>>.from(response);
    final clashes = <Map<String, dynamic>>[];

    for (final approvedReq in approved) {
      final approvedSlots =
          List<Map<String, dynamic>>.from(approvedReq['slots'] ?? []);

      for (final ps in pendingSlots) {
        for (final as_ in approvedSlots) {
          if (ps['date'] == as_['date']) {
            final pStart = _timeToMinutes(ps['from'] ?? '00:00');
            final pEnd   = _timeToMinutes(ps['to']   ?? '00:00');
            final aStart = _timeToMinutes(as_['from'] ?? '00:00');
            final aEnd   = _timeToMinutes(as_['to']   ?? '00:00');

            if (pStart < aEnd && pEnd > aStart) {
              clashes.add({
                ...approvedReq,
                'clash_date': ps['date'],
                'clash_from': as_['from'],
                'clash_to':   as_['to'],
              });
              break;
            }
          }
        }
      }
    }

    return clashes;
  }

  static int _timeToMinutes(String time) {
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

  static String minutesToTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }
}