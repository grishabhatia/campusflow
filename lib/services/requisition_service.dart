import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ Direct import
import '../models/requisition_model.dart';

class RequisitionService {
  // ✅ Direct Supabase client
  final supabase = Supabase.instance.client;

  Future<void> submitRequisition(RequisitionModel req) async {
    await supabase.from('requisitions').insert(req.toMap());
  }

  Future<List<Map<String, dynamic>>> getMyRequisitions(String userId) async {
    final response = await supabase
        .from('requisitions')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getLatestRequisition(String userId) async {
    try {
      final response = await supabase
          .from('requisitions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateStatus(String id, String status) async {
    await supabase
        .from('requisitions')
        .update({'status': status})
        .eq('id', id);
  }

  Future<Map<String, dynamic>?> getRequisitionById(String id) async {
    try {
      final response = await supabase
          .from('requisitions')
          .select('*')
          .eq('id', id)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }
}