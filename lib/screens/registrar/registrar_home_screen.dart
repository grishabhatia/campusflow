import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/email_service.dart';

class RegistrarHomeScreen extends StatefulWidget {
  const RegistrarHomeScreen({super.key});

  @override
  State<RegistrarHomeScreen> createState() => _RegistrarHomeScreenState();
}

class _RegistrarHomeScreenState extends State<RegistrarHomeScreen> {
  final _auth = SupabaseAuthService();
  final _emailService = EmailService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _events = [];

  int get _pendingCount =>
      _events.where((e) => e['registrar_approved'] != true).length;
  int get _approvedCount =>
      _events.where((e) => e['registrar_approved'] == true).length;
  int get _totalCount => _events.length;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      // ✅ Sirf admin + dept approved events
      final response = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .eq('admin_approved', true)
          .eq('dept_approved', true)
          .order('created_at', ascending: false);

      setState(() {
        _events = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      debugPrint('📋 Registrar Events: ${_events.length}');
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registrarApprove(String id) async {
    try {
      // ✅ Final approval — status approved
      await Supabase.instance.client
          .from('requisitions')
          .update({
            'registrar_approved': true,
            'registrar_approved_at': DateTime.now().toIso8601String(),
            'status': 'approved', // ✅ Student ko approved dikhega
          })
          .eq('id', id);

      // ✅ Event Coordinator ko final approval email bhejo
      final event = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (event != null) {
        final userEmail = event['user_email'] ?? '';
        final userName = userEmail.split('@')[0];

        try {
          await _emailService.sendApprovalEmail(
            toEmail: userEmail,
            userName: userName,
            eventName: event['purpose'] ?? 'Untitled',
            eventDate: event['booking_date'] ?? 'N/A',
            eventTime:
                '${event['event_time_from']} → ${event['event_time_to']}',
            venue: event['venue'] ?? 'N/A',
          );
          debugPrint('✅ Final approval email sent to $userEmail');
        } catch (e) {
          debugPrint('⚠️ Email error: $e');
        }
      }

      // ✅ FIX: Message changed from "Student notified" to "Event Coordinator notified"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Final Approval Done! Event Coordinator notified.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _registrarReject(String id) async {
    try {
      await Supabase.instance.client
          .from('requisitions')
          .update({
            'registrar_approved': false,
            'status': 'rejected',
          })
          .eq('id', id);

      // ✅ Rejection email
      final event = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (event != null) {
        final userEmail = event['user_email'] ?? '';
        if (userEmail.isNotEmpty) {
          try {
            await _emailService.sendRejectionEmail(
              toEmail: userEmail,
              userName: userEmail.split('@')[0],
              eventName: event['purpose'] ?? 'Untitled',
              venue: event['venue'] ?? 'N/A',
              reason: 'Rejected by Registrar',
            );
          } catch (e) {
            debugPrint('⚠️ Email error: $e');
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Registrar Rejected'),
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
    final isRegistrarApproved = event['registrar_approved'] == true;
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
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
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
                          const Text(
                            'Registrar Final Approval',
                            style: TextStyle(
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
                      // ✅ APPROVED BY ADMIN & DEPARTMENT NOTE
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
                                    'APPROVED BY ADMIN & DEPARTMENT',
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
                              'This event has been approved by Admin and Department. Registrar final approval is now pending.',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Info
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  _infoRow('Admin Approved',
                                      event['admin_approved_at'] != null
                                          ? '✅ Yes'
                                          : '⏳ Pending'),
                                  _infoRow('Dept Approved',
                                      event['dept_approved_at'] != null
                                          ? '✅ Yes'
                                          : '⏳ Pending'),
                                  _infoRow('Department',
                                      event['department'] ?? 'N/A'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Next Step
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.orange.withAlpha(50)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange, size: 16),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Next Step: Registrar final approval required to confirm this event.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
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
              if (!isRegistrarApproved)
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
                            _registrarApprove(event['id']);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Final Approve'),
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
                            _registrarReject(event['id']);
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
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
        title: const Text('Registrar Dashboard'),
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
                      _statCard('Final Approved', _approvedCount, Colors.green),
                      const SizedBox(width: 8),
                      _statCard('Total', _totalCount, const Color(0xFF1565C0)),
                    ],
                  ),
                ),
                Expanded(
                  child: _events.isEmpty
                      ? const Center(
                          child: Text('No events pending registrar approval'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _events.length,
                          itemBuilder: (ctx, i) {
                            final event = _events[i];
                            final isApproved =
                                event['registrar_approved'] == true;

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
                                      Text(
                                        event['purpose'] ?? 'Untitled',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('📍 ${event['venue'] ?? 'N/A'}'),
                                      Text(
                                          '📅 ${event['booking_date'] ?? 'N/A'}'),
                                      Text(
                                          '🏢 ${event['department'] ?? 'N/A'}'),
                                      Text(
                                          '👤 ${event['user_email'] ?? 'N/A'}'),
                                      const SizedBox(height: 4),
                                      Text(
                                        '👆 Tap for final approval',
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