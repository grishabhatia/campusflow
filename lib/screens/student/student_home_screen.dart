import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/clash_detection_service.dart';
import '../../widgets/clash_popup_dialog.dart';
import 'create_event_screen.dart';
import 'edit_event_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _auth         = SupabaseAuthService();
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
      final userId  = _auth.currentUserId;
      final supabase = Supabase.instance.client;

      if (userId != null) {
        final userResponse = await supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        final eventsResponse = await supabase
            .from('requisitions')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _userData = userResponse;
            _events   = List<Map<String, dynamic>>.from(eventsResponse);
          });
        }

        await _checkClashNotifications();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ✅ FIXED: Check Clash Notifications with all parameters
  Future<void> _checkClashNotifications() async {
    for (final event in _events) {
      final status   = event['status'] ?? '';
      final notified = event['clash_notification_sent'] ?? false;

      if (status == 'pending' && notified == false) {
        final clashes = await _clashService.checkClashes(event);
        if (clashes.isNotEmpty) {
          await _clashService.saveClashDetails(event['id'], clashes);
          await _clashService.markNotificationSent(event['id']);
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => ClashPopupDialog(
              eventName: event['purpose'] ?? 'Untitled',
              roomName: event['venue'] ?? 'N/A',
              eventDate: event['booking_date'] ?? 'N/A',
              startTime: event['event_time_from'] ?? 'N/A',
              endTime: event['event_time_to'] ?? 'N/A',
              clashes: clashes.map((c) => c.toMap()).toList(),
            ),
          );
          break;
        }
      }
    }
  }

  // Check if edit button should show (within 24 hours)
  bool _canEdit(Map<String, dynamic> event) {
    if (event['status'] != 'approved') return false;
    try {
      final createdAt  = DateTime.parse(event['created_at']);
      final difference = DateTime.now().difference(createdAt);
      return difference.inHours <= 24;
    } catch (_) {
      return false;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':  return Colors.green;
      case 'rejected':  return Colors.red;
      case 'cancelled': return Colors.grey;   // ✅ Added
      default:          return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':  return '✅ Approved';
      case 'rejected':  return '❌ Rejected';
      case 'cancelled': return '❌ Cancelled'; // ✅ Added
      default:          return '⏳ Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Hide cancelled events from list (Optional)
    final activeEvents = _events.where((e) => e['status'] != 'cancelled').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusFlow Smart'),
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
                    // ── Welcome ─────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_userData?['name'] ?? 'Student'}! 👋',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manav Rachna International Institute\nof Research and Studies',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Create Button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateEventScreen()),
                          );
                          if (result == true) _loadData();
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
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── My Events Header ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('My Events',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text('${activeEvents.length} total',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Events List ──────────────────────────────────────────
                    Expanded(
                      child: activeEvents.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy,
                                      size: 60, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text('No events yet',
                                      style: TextStyle(
                                          color: Colors.grey[600])),
                                  Text('Create your first event request!',
                                      style: TextStyle(
                                          color: Colors.grey[500])),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: activeEvents.length,
                              itemBuilder: (context, index) {
                                final event  = activeEvents[index];
                                final status = event['status'] ?? 'pending';
                                final color  = _statusColor(status);
                                final label  = _statusLabel(status);
                                final canEditEvent = _canEdit(event);
                                final aiApproved   =
                                    event['ai_approved'] == true;
                                final clashDetected =
                                    event['clash_detected'] == true;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: clashDetected
                                        ? const BorderSide(
                                            color: Colors.red, width: 1.5)
                                        : BorderSide.none,
                                  ),
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ── Top row: title + status ──────
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                event['purpose'] ?? 'Untitled',
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                    alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border:
                                                    Border.all(color: color),
                                              ),
                                              child: Text(
                                                label,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: color),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // ── Venue ────────────────────────
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on,
                                                size: 13,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                event['venue'] ?? 'N/A',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600]),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        // ── Date + Time ──────────────────
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today,
                                                size: 13,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${event['booking_date'] ?? 'N/A'}  •  ${event['event_time_from'] ?? ''} → ${event['event_time_to'] ?? ''}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // ── Badges row ───────────────────
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (aiApproved)
                                              _badge('🤖 AI Approved',
                                                  Colors.green),
                                            if (clashDetected)
                                              _badge('⚠️ Clash Detected',
                                                  Colors.red),
                                          ],
                                        ),

                                        // ── Edit Button ──────────────────
                                        if (canEditEvent) ...[
                                          const SizedBox(height: 8),
                                          const Divider(height: 1),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.info_outline,
                                                  size: 12,
                                                  color: Colors.blue),
                                              const SizedBox(width: 4),
                                              const Expanded(
                                                child: Text(
                                                  'Editable within 24 hours of approval',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.blue),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  final result =
                                                      await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          EditEventScreen(
                                                              requisition:
                                                                  event),
                                                    ),
                                                  );
                                                  if (result == true) {
                                                    _loadData();
                                                  }
                                                },
                                                icon: const Icon(Icons.edit,
                                                    size: 14),
                                                label: const Text('Edit',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFF1565C0),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }
}