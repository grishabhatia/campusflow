import '../main.dart';
import '../models/event_model.dart';

class EventService {
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
}