import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/clash_detection_service.dart';
import '../../widgets/clash_popup_dialog.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _auth = SupabaseAuthService();
  final _clashService = ClashDetectionService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUserId;
      if (userId != null) {
        final supabase = Supabase.instance.client;

        // Get user data
        final userResponse = await supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
        setState(() => _userData = userResponse);

        // Get user's events with room details
        final eventsResponse = await supabase
            .from('events')
            .select('*, rooms(*)')
            .eq('organizer_id', userId)
            .order('created_at', ascending: false);
        _events = List<Map<String, dynamic>>.from(eventsResponse);

        // Check for pending events and show clash popup if needed
        await _checkPendingEvents();
      }
    } catch (e) {
      print('Error loading data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _checkPendingEvents() async {
    for (final event in _events) {
      if (event['status'] == 'pending' || event['status'] == 'approved') {
        // Check if clash exists
        final clashResult = await _clashService.checkClash(event);
        if (clashResult.hasClash) {
          // Show popup for the first clash
          final firstClash = clashResult.clashes.first;
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ClashPopupDialog(
              eventName: event['event_name'] ?? 'Untitled',
              roomName: event['rooms']?['room_name'] ?? 'N/A',
              eventDate: event['event_date'] ?? 'N/A',
              startTime: _clashService.formatTime(event['start_time'] ?? 0),
              endTime: _clashService.formatTime(event['end_time'] ?? 0),
              clashes: clashResult.clashes,
            ),
          );
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_userData?['name'] ?? 'Student'}! 👋',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Organize your events easily with AI',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ✅ CREATE EVENT BUTTON — WORKING
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          print('🔘 Create Event button clicked!');
                          Navigator.pushNamed(context, '/create-event');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'CREATE NEW EVENT REQUEST',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // My Events
                    const Text(
                      'My Events',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _events.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No events yet',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'Create your first event request!',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _events.length,
                              itemBuilder: (context, index) {
                                final event = _events[index];
                                final status = event['status'] ?? 'pending';
                                Color statusColor = Colors.orange;
                                String statusLabel = 'Pending';
                                if (status == 'approved') {
                                  statusColor = Colors.green;
                                  statusLabel = '✅ Approved';
                                } else if (status == 'rejected') {
                                  statusColor = Colors.red;
                                  statusLabel = '❌ Rejected';
                                }

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(event['event_name'] ?? 'Untitled'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('📌 ${event['rooms']?['room_name'] ?? 'N/A'}'),
                                        Text('📅 ${event['event_date']} | 🕐 ${_formatTime(event['start_time'])} - ${_formatTime(event['end_time'])}'),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                        if (event['ai_approved'] == true) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '🤖 AI',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    onTap: () {
                                      print('📱 Event tapped: ${event['event_name']}');
                                      // TODO: Navigate to event detail
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return 'N/A';
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${min.toString().padLeft(2, '0')} $period';
  }
}