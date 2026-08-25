import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/ai_approval_service.dart';
import '../../widgets/ai_badge.dart';
import '../../widgets/clash_badge.dart';
import '../../widgets/clash_popup_dialog.dart';  // ✅ Add this import

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _auth = SupabaseAuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _pendingEvents = [];
  List<Map<String, dynamic>> _approvedEvents = [];
  List<Map<String, dynamic>> _rejectedEvents = [];

  // Filters
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

        // Load user data
        final userResponse = await supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
        setState(() => _userData = userResponse);

        // Load all events with room details
        final eventsResponse = await supabase
            .from('events')
            .select('*, rooms(*)')
            .order('created_at', ascending: false);

        _events = List<Map<String, dynamic>>.from(eventsResponse);

        // Filter events
        _pendingEvents = _events.where((e) => e['status'] == 'pending').toList();
        _approvedEvents = _events.where((e) => e['status'] == 'approved').toList();
        _rejectedEvents = _events.where((e) => e['status'] == 'rejected').toList();

        // Check for clashes in pending events
        await _checkClashes();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _checkClashes() async {
    final supabase = Supabase.instance.client;
    for (final event in _pendingEvents) {
      final clashes = await _detectClashes(event);
      if (clashes.isNotEmpty) {
        await supabase.from('events').update({
          'clash_detected': true,
          'clash_details': clashes,
        }).eq('id', event['id']);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _detectClashes(Map<String, dynamic> newEvent) async {
    final supabase = Supabase.instance.client;
    final clashes = <Map<String, dynamic>>[];

    try {
      final approvedEvents = await supabase
          .from('events')
          .select('*, rooms(*)')
          .eq('event_date', newEvent['event_date'])
          .eq('status', 'approved');

      for (final existing in approvedEvents) {
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
          });
        }
      }
    } catch (e) {
      debugPrint('Error detecting clashes: $e');
    }

    return clashes;
  }

  Future<void> _approveEvent(String eventId, bool isAutoApproved) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('events')
          .update({
            'status': 'approved',
            'admin_approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventId);

      // Log activity
      await supabase.from('activity_logs').insert({
        'admin_id': _auth.currentUserId,
        'action': 'approved',
        'event_id': eventId,
        'details': isAutoApproved ? 'Auto-approved by AI' : 'Approved by Admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Event Approved'), backgroundColor: Colors.green),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _rejectEvent(String eventId) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('events')
          .update({
            'status': 'rejected',
            'admin_rejected_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventId);

      // Log activity
      await supabase.from('activity_logs').insert({
        'admin_id': _auth.currentUserId,
        'action': 'rejected',
        'event_id': eventId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Event Rejected'), backgroundColor: Colors.red),
      );
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:${min.toString().padLeft(2, '0')} $period';
  }

  List<Map<String, dynamic>> get _filteredEvents {
    var events = _events;

    // Apply status filter
    if (_selectedFilter != 'All') {
      events = events.where((e) => e['status'] == _selectedFilter.toLowerCase()).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      events = events.where((e) =>
          (e['event_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e['purpose'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e['organization'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e['rooms']?['room_name'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _filteredEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
          : Column(
              children: [
                // Stats Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard('Pending', _pendingEvents.length, Colors.orange),
                      _buildStatCard('Approved', _approvedEvents.length, Colors.green),
                      _buildStatCard('Rejected', _rejectedEvents.length, Colors.red),
                      _buildStatCard('Total', _events.length, Colors.blue),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Pending', 'Approved', 'Rejected'].map((filter) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() => _selectedFilter = selected ? filter : 'All');
                            },
                            backgroundColor: Colors.grey.shade200,
                            selectedColor: Colors.blue.shade100,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Events List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: filteredEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No events found',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, index) {
                              final event = filteredEvents[index];
                              final roomName = event['rooms']?['room_name'] ?? 'N/A';
                              final isPending = event['status'] == 'pending';
                              final isApproved = event['status'] == 'approved';
                              final isRejected = event['status'] == 'rejected';
                              final isAutoApproved = event['ai_approved'] == true;
                              final clashDetected = event['clash_detected'] == true;
                              final score = event['ai_score'] ?? 0;
                              final reason = event['ai_reason'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isPending ? Colors.orange : 
                                           isApproved ? Colors.green : 
                                           Colors.red,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              event['event_name'] ?? 'Untitled',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          StatusBadge(status: event['status']),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('📌 $roomName'),
                                      Text('📅 ${event['event_date']} | 🕐 ${_formatTime(event['start_time'])} - ${_formatTime(event['end_time'])}'),
                                      Text('👥 ${event['expected_crowd'] ?? 'N/A'}'),
                                      if (event['purpose'] != null) Text('📝 ${event['purpose']}'),
                                      const SizedBox(height: 8),

                                      // AI Badge
                                      Row(
                                        children: [
                                          AiBadge(
                                            isAutoApproved: isAutoApproved,
                                            score: score,
                                            reason: reason,
                                          ),
                                          if (isPending && clashDetected) ...[
                                            const SizedBox(width: 8),
                                            const ClashBadge(),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Action Buttons (only for pending)
                                      if (isPending) ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _approveEvent(event['id'], isAutoApproved),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                icon: const Icon(Icons.check),
                                                label: const Text('Approve'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _rejectEvent(event['id']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                icon: const Icon(Icons.close),
                                                label: const Text('Reject'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // View Details button
                                        TextButton(
                                          onPressed: () {
                                            // Navigate to event detail
                                          },
                                          child: const Text('View Details'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status Badge Widget
class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = '✅ Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = '❌ Rejected';
        break;
      case 'pending':
        color = Colors.orange;
        label = '⏳ Pending';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}