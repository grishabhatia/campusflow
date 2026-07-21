import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ Direct import

class ActivityLogService {
  // ✅ Direct Supabase client
  final supabase = Supabase.instance.client;

  Future<void> log({
    required String adminId,
    required String action,
    String? requisitionId,
    String? details,
  }) async {
    try {
      await supabase.from('activity_logs').insert({
        'admin_id': adminId,
        'action': action,
        if (requisitionId != null) 'requisition_id': requisitionId,
        if (details != null) 'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log silently — don't break main flow
    }
  }

  Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 20}) async {
    final response = await supabase
        .from('activity_logs')
        .select('*, users(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }
}