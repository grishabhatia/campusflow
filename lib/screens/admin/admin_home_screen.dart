import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _auth = SupabaseAuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];
  String _filter = 'all'; // all, pending, approved, rejected
  String _searchQuery = '';

  // ✅ Stats
  int get _pendingCount => _events.where((e) => e['status'] == 'pending').length;
  int get _approvedCount => _events.where((e) => e['status'] == 'approved').length;
  int get _rejectedCount => _events.where((e) => e['status'] == 'rejected').length;
  int get _totalCount => _events.length;

  // ✅ Filtered events
  List<Map<String, dynamic>> get _filteredEvents {
    var events = _events;

    // Status filter
    if (_filter != 'all') {
      events = events.where((e) => e['status'] == _filter).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      events = events.where((e) =>
          (e['purpose'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e['venue'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e['user_email'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return events;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _events = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading events: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('requisitions')
          .update({'status': status})
          .eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Event $status successfully'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ Helper: Email se naam extract karo
  String _getDisplayNameFromEmail(String email) {
    try {
      String username = email.split('@')[0];
      String cleanName = username.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (cleanName.isEmpty) return 'User';
      return cleanName[0].toUpperCase() + cleanName.substring(1).toLowerCase();
    } catch (e) {
      return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _filteredEvents;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
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
                // ── Stats Cards ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _statCard('Pending', _pendingCount, Colors.orange),
                      const SizedBox(width: 8),
                      _statCard('Approved', _approvedCount, Colors.green),
                      const SizedBox(width: 8),
                      _statCard('Rejected', _rejectedCount, Colors.red),
                      const SizedBox(width: 8),
                      _statCard('Total', _totalCount, const Color(0xFF1565C0)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Search Bar ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Filter Chips ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      const SizedBox(width: 6),
                      _filterChip('Pending', 'pending'),
                      const SizedBox(width: 6),
                      _filterChip('Approved', 'approved'),
                      const SizedBox(width: 6),
                      _filterChip('Rejected', 'rejected'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Events List ──────────────────────────────────────────────
                Expanded(
                  child: filteredEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No ${_filter == 'all' ? '' : _filter} events found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredEvents.length,
                          itemBuilder: (ctx, index) {
                            final event = filteredEvents[index];
                            final status = event['status'] ?? 'pending';
                            final isApproved = status == 'approved';
                            final isRejected = status == 'rejected';
                            final isPending = status == 'pending';
                            final isAutoApproved = event['ai_approved'] == true;
                            final clashDetected = event['clash_detected'] == true;
                            final score = event['ai_score'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isApproved
                                      ? Colors.green
                                      : isRejected
                                          ? Colors.red
                                          : Colors.orange,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ── Title + Status ──────────────────────
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            event['purpose'] ?? 'Untitled',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isApproved
                                                ? Colors.green.withAlpha(20)
                                                : isRejected
                                                    ? Colors.red.withAlpha(20)
                                                    : Colors.orange.withAlpha(20),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isApproved
                                                  ? Colors.green
                                                  : isRejected
                                                      ? Colors.red
                                                      : Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // ── Venue ──────────────────────────────
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          event['venue'] ?? 'N/A',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),

                                    // ── Date + Time ────────────────────────
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${event['booking_date'] ?? 'N/A'} | ${event['event_time_from'] ?? ''} - ${event['event_time_to'] ?? ''}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),

                                    // ── User ────────────────────────────────
                                    Row(
                                      children: [
                                        const Icon(Icons.person,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          _getDisplayNameFromEmail(
                                              event['user_email'] ?? ''),
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),

                                    // ── Badges ──────────────────────────────
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (isAutoApproved)
                                          _badge('🤖 AI Approved ($score%)', Colors.green),
                                        if (clashDetected && isPending)
                                          _badge('⚠️ Clash Detected', Colors.red),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // ── Action Buttons ──────────────────────
                                    if (isPending)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _updateStatus(
                                                  event['id'], 'approved'),
                                              icon: const Icon(Icons.check,
                                                  size: 16),
                                              label: const Text('Approve'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _updateStatus(
                                                  event['id'], 'rejected'),
                                              icon: const Icon(Icons.close,
                                                  size: 16),
                                              label: const Text('Reject'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: const Color(0xFF1565C0).withAlpha(30),
      checkmarkColor: const Color(0xFF1565C0),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}