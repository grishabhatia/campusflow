import 'package:supabase_flutter/supabase_flutter.dart';  // ✅ Direct import
import '../models/event_model.dart';

class EventService {
  // ✅ Direct Supabase client
  final supabase = Supabase.instance.client;

  // Fetch rooms where capacity >= expectedCrowd
  Future<List<Map<String, dynamic>>> getAvailableRooms(int expectedCrowd) async {
    final response = await supabase
        .from('rooms')
        .select('*')
        .gte('capacity', expectedCrowd)
        .eq('is_active', true)
        .order('capacity', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Insert event into events table
  Future<void> createEvent(EventModel event) async {
    await supabase.from('events').insert(event.toMap());
  }

  // Fetch events for current student
  Future<List<Map<String, dynamic>>> getMyEvents(String userId) async {
    final response = await supabase
        .from('events')
        .select('*, rooms(room_name, building)')
        .eq('organizer_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Fetch single event by ID
  Future<Map<String, dynamic>?> getEventById(String eventId) async {
    try {
      final response = await supabase
          .from('events')
          .select('*, rooms(*)')
          .eq('id', eventId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Update event status (approve/reject)
  Future<void> updateEventStatus(String eventId, String status) async {
    await supabase
        .from('events')
        .update({'status': status})
        .eq('id', eventId);
  }
}