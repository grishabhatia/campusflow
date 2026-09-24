import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';

class DepartmentHomeScreen extends StatefulWidget {
  final String department; // "CSE" or "Civil"

  const DepartmentHomeScreen({super.key, required this.department});

  @override
  State<DepartmentHomeScreen> createState() => _DepartmentHomeScreenState();
}

class _DepartmentHomeScreenState extends State<DepartmentHomeScreen> {
  final _auth = SupabaseAuthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];

  int get _pendingCount =>
      _events.where((e) => e['dept_approved'] != true).length;
  int get _approvedCount =>
      _events.where((e) => e['dept_approved'] == true).length;
  int get _totalCount => _events.length;

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
          .eq('admin_approved', true)
          .eq('department', widget.department)
          .order('created_at', ascending: false);

      setState(() {
        _events = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      debugPrint('📋 ${widget.department} Department Events: ${_events.length}');
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ UPDATED: Dept approve now sets status = 'pending' (waiting for registrar)
  Future<void> _deptApprove(String id) async {
    try {
      await Supabase.instance.client
          .from('requisitions')
          .update({
            'dept_approved': true,
            'dept_approved_at': DateTime.now().toIso8601String(),
            'status': 'pending', // ✅ Now waiting for Registrar approval
          })
          .eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Department Approved! Now sent to Registrar.'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deptReject(String id) async {
    try {
      await Supabase.instance.client
          .from('requisitions')
          .update({
            'dept_approved': false,
            'status': 'rejected',
          })
          .eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Department Rejected'),
          backgroundColor: Colors.red,
        ),
      );
      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEventDetails(Map<String, dynamic> event) {
    final isDeptApproved = event['dept_approved'] == true;
    final fac = event['facilities'] as Map<String, dynamic>? ?? {};
    final sigs = event['signatures'] as Map<String, dynamic>? ?? {};
    final initiated = sigs['initiated'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['purpose'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.department} Department',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ ADMIN APPROVAL NOTE
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.green.withAlpha(50), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'APPROVED BY ADMIN',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'This event has been approved by the Admin. Department approval is now pending.',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      _sectionTitle('📋 EVENT DETAILS'),
                      _detailRow('Venue', event['venue'] ?? 'N/A'),
                      _detailRow('Date', event['booking_date'] ?? 'N/A'),
                      _detailRow('Time',
                          '${event['event_time_from']} → ${event['event_time_to']}'),
                      _detailRow('Purpose', event['purpose'] ?? 'N/A'),
                      _detailRow('Strength',
                          event['expected_strength'] ?? 'N/A'),

                      const SizedBox(height: 16),
                      _sectionTitle('🎯 FACILITIES'),
                      _facilityRow('Lamp', fac['lamp']),
                      _facilityRow('Water', fac['water']),
                      _facilityRow('Bouquet', fac['bouquet']),
                      _facilityRow('Photography', fac['photography']),
                      _facilityRow('Videography', fac['videography']),

                      const SizedBox(height: 16),
                      _sectionTitle('✍️ INITIATED BY'),
                      _detailRow('Name', initiated['name'] ?? 'N/A'),
                      _detailRow('Sign', initiated['sign'] ?? 'N/A'),
                      _detailRow('Phone', initiated['phone'] ?? 'N/A'),

                      const SizedBox(height: 16),
                      _sectionTitle('👤 REQUESTED BY'),
                      _detailRow('Email', event['user_email'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),

              // ── Buttons ─────────────────────────────────────────────
              if (!isDeptApproved)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deptApprove(event['id']);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Dept Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deptReject(event['id']);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ Dept approved — Waiting for Registrar
              if (isDeptApproved)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '✅ Department Approved! Now waiting for Registrar final approval.',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      );

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  Widget _facilityRow(String label, dynamic value) {
    bool selected = false;
    if (value is bool) selected = value;
    if (value is Map) selected = value['selected'] == true;
    if (!selected) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('${widget.department} Department'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _statCard('Pending', _pendingCount, Colors.orange),
                      const SizedBox(width: 8),
                      _statCard('Approved', _approvedCount, Colors.green),
                      const SizedBox(width: 8),
                      _statCard('Total', _totalCount, const Color(0xFF1565C0)),
                    ],
                  ),
                ),
                Expanded(
                  child: _events.isEmpty
                      ? const Center(
                          child: Text('No events pending dept approval'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _events.length,
                          itemBuilder: (ctx, i) {
                            final event = _events[i];
                            final isApproved = event['dept_approved'] == true;

                            return InkWell(
                              onTap: () => _showEventDetails(event),
                              borderRadius: BorderRadius.circular(12),
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isApproved
                                        ? Colors.green
                                        : Colors.orange,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                          // ✅ Status badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isApproved
                                                  ? Colors.green.withAlpha(20)
                                                  : Colors.orange.withAlpha(20),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isApproved
                                                  ? 'DEPT ✓'
                                                  : 'DEPT PENDING',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isApproved
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text('📍 ${event['venue'] ?? 'N/A'}'),
                                      Text(
                                          '📅 ${event['booking_date'] ?? 'N/A'}'),
                                      Text(
                                          '👤 ${event['user_email'] ?? 'N/A'}'),
                                      const SizedBox(height: 4),
                                      Text(
                                        '👆 Tap to view & approve',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[400],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _statCard(String label, int count, Color color) => Expanded(
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
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
}