import '../main.dart';
import '../models/clash_model.dart';

class ClashDetectionService {
  static int _toMin(String time) {
    try {
      time = time.trim();
      final isPM = time.toUpperCase().contains('PM');
      final isAM = time.toUpperCase().contains('AM');
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

  /// Returns list of ClashModel — empty means no clash.
  Future<List<ClashModel>> checkClashes(
      Map<String, dynamic> pendingReq) async {
    final venue     = pendingReq['venue'] as String? ?? '';
    final pendingId = pendingReq['id']   as String? ?? '';
    final pendingSlots =
        List<Map<String, dynamic>>.from(pendingReq['slots'] ?? []);

    // Fetch all approved requisitions for same venue
    final response = await supabase
        .from('requisitions')
        .select('*, users(name)')
        .eq('venue', venue)
        .eq('status', 'approved')
        .neq('id', pendingId);

    final approved = List<Map<String, dynamic>>.from(response);
    final clashes  = <ClashModel>[];

    for (final approvedReq in approved) {
      final approvedSlots =
          List<Map<String, dynamic>>.from(approvedReq['slots'] ?? []);

      for (final ps in pendingSlots) {
        for (final as_ in approvedSlots) {
          if (ps['date'] == as_['date']) {
            final pStart = _toMin(ps['from'] ?? '');
            final pEnd   = _toMin(ps['to']   ?? '');
            final aStart = _toMin(as_['from'] ?? '');
            final aEnd   = _toMin(as_['to']   ?? '');

            if (pStart < aEnd && pEnd > aStart) {
              clashes.add(ClashModel(
                clashingEventId:
                    approvedReq['id'] ?? '',
                clashingEventName:
                    approvedReq['purpose'] ?? 'Another Event',
                venue: venue,
                date:  ps['date']   ?? '',
                fromTime: as_['from'] ?? '',
                toTime:   as_['to']   ?? '',
                organizerName:
                    (approvedReq['users']
                        as Map<String, dynamic>?)?['name'] ??
                    'Unknown',
              ));
              break;
            }
          }
        }
      }
    }
    return clashes;
  }

  Future<void> saveClashDetails(
      String id, List<ClashModel> clashes) async {
    await supabase.from('requisitions').update({
      'clash_detected': clashes.isNotEmpty,
      'clash_details':  clashes.map((c) => c.toMap()).toList(),
    }).eq('id', id);
  }

  Future<void> markNotificationSent(String id) async {
    await supabase.from('requisitions').update({
      'clash_notification_sent': true,
    }).eq('id', id);
  }
}