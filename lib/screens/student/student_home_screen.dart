import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/event_service.dart';
import 'create_event_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _auth = SupabaseAuthService();
  final _eventService = EventService();
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _myEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = _auth.currentUserId;
      if (userId != null) {
        final userResponse = await supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
        final events = await _eventService.getMyEvents(userId);
        setState(() {
          _userData = userResponse;
          _myEvents = events;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
    }
    setState(() => _isLoading = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome header
                    Text(
                      'Welcome, ${_userData?['name'] ?? 'Student'}! 👋',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organize your events easily with AI',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),

                    // Create event button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateEventScreen(),
                            ),
                          );
                          if (result == true) _loadData(); // refresh on success
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
                    const SizedBox(height: 28),

                    // My Events section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Events',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_myEvents.length} total',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Events list
                    if (_myEvents.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy,
                                  size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No events yet',
                                  style: TextStyle(color: Colors.grey[600])),
                              Text('Create your first event request!',
                                  style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        ),
                      )
                    else
                      ...(_myEvents.map((event) {
                        final status = event['status'] ?? 'pending';
                        final roomName =
                            event['rooms']?['room_name'] ?? 'Room TBD';
                        final building =
                            event['rooms']?['building'] ?? '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event['event_name'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: _statusColor(status)),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                            color: _statusColor(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text(event['event_date'] ?? '',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13)),
                                    const SizedBox(width: 16),
                                    Icon(Icons.meeting_room,
                                        size: 14, color: Colors.grey[500]),
                                    const SizedBox(width: 4),
                                    Text('$roomName, $building',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList()),
                  ],
                ),
              ),
            ),
    );
  }
}