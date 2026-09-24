import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/email_service.dart';
import '../../services/excel_service.dart';   // ✅ NEW

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _auth = SupabaseAuthService();
  final _emailService = EmailService();
  bool _isLoading = true;
  bool _isExporting = false;   // ✅ NEW
  List<Map<String, dynamic>> _events = [];
  String _filter = 'all';
  String _searchQuery = '';

  int get _pendingCount => _events.where((e) => e['status'] == 'pending').length;
  int get _approvedCount => _events.where((e) => e['status'] == 'approved').length;
  int get _rejectedCount => _events.where((e) => e['status'] == 'rejected').length;
  int get _totalCount => _events.length;

  List<Map<String, dynamic>> get _filteredEvents {
    var events = _events;

    if (_filter != 'all') {
      events = events.where((e) => e['status'] == _filter).toList();
    }

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

  // ✅ Excel Export Function
  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      await ExcelService().exportApprovedEvents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Excel downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Excel error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      if (status == 'approved') {
        await Supabase.instance.client
            .from('requisitions')
            .update({
              'admin_approved': true,
              'admin_approved_at': DateTime.now().toIso8601String(),
              'status': 'pending',
            })
            .eq('id', id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Admin Approved! department approval pending.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (status == 'rejected') {
        await Supabase.instance.client
            .from('requisitions')
            .update({
              'status': 'rejected',
              'admin_approved': false,
            })
            .eq('id', id);

        final event = await Supabase.instance.client
            .from('requisitions')
            .select('*')
            .eq('id', id)
            .maybeSingle();

        if (event != null) {
          String userEmail = event['user_email'] ?? '';
          if (userEmail.isEmpty) {
            final userRow = await Supabase.instance.client
                .from('users')
                .select('email')
                .eq('id', event['user_id'])
                .maybeSingle();
            userEmail = userRow?['email'] ?? '';
          }

          if (userEmail.isNotEmpty) {
            try {
              await _emailService.sendRejectionEmail(
                toEmail: userEmail,
                userName: _getDisplayNameFromEmail(userEmail),
                eventName: event['purpose'] ?? 'Untitled',
                venue: event['venue'] ?? 'N/A',
                reason: 'Admin rejected the request',
              );
            } catch (e) {
              debugPrint('⚠️ Rejection email error: $e');
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Admin Rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }

      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

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

  void _showEventDetails(Map<String, dynamic> event) {
    final status = event['status'] ?? 'pending';
    final isPending = status == 'pending';
    final adminApproved = event['admin_approved'] == true;
    final deptApproved = event['dept_approved'] == true;

    final fac = event['facilities'] as Map<String, dynamic>? ?? {};
    final sigs = event['signatures'] as Map<String, dynamic>? ?? {};
    final initiated = sigs['initiated'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                            event['purpose'] ?? 'Untitled Event',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: adminApproved ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  adminApproved ? 'ADMIN ✓' : 'ADMIN PENDING',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: deptApproved ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  deptApproved ? 'DEPT ✓' : 'DEPT PENDING',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('📋 EVENT DETAILS'),
                      _detailRow('Venue', event['venue'] ?? 'N/A'),
                      _detailRow('Booking Date', event['booking_date'] ?? 'N/A'),
                      _detailRow('Booking Time', event['booking_time'] ?? 'N/A'),
                      _detailRow('Event Time From', event['event_time_from'] ?? 'N/A'),
                      _detailRow('Event Time To', event['event_time_to'] ?? 'N/A'),
                      _detailRow('Institute', event['institute_name'] ?? 'N/A'),
                      _detailRow('Purpose', event['purpose'] ?? 'N/A'),
                      _detailRow('Expected Strength', event['expected_strength'] ?? 'N/A'),
                      _detailRow('Extra Furniture', event['extra_furniture'] ?? 'None'),
                      _detailRow('Department', event['department'] ?? 'N/A'),
                      const SizedBox(height: 16),

                      _sectionTitle('🎯 REQUIRED FACILITIES'),
                      _facilityRow('Lamp', fac['lamp']),
                      _facilityRow('Water Arrangements', fac['water']),
                      _facilityRow('Bouquet', fac['bouquet']),
                      _facilityRow('Still Photography', fac['photography']),
                      _facilityRow('Videography', fac['videography']),
                      _facilityRow('Projector', fac['projector']),
                      if (fac['laptopIT']?['selected'] == true)
                        _facilityRow('Laptop with IT Person', fac['laptopIT']),
                      if (fac['podiumMike']?['selected'] == true)
                        _facilityRow('Podium Mike', fac['podiumMike']),
                      if (fac['cordlessMike']?['selected'] == true)
                        _facilityRow('Cordless Mike', fac['cordlessMike']),
                      if (fac['collarMike']?['selected'] == true)
                        _facilityRow('Collar Mike', fac['collarMike']),
                      const SizedBox(height: 16),

                      _sectionTitle('✍️ INITIATED BY (DEPARTMENT)'),
                      _detailRow('Name', initiated['name'] ?? 'N/A'),
                      _detailRow('Sign / Designation', initiated['sign'] ?? 'N/A'),
                      _detailRow('Phone', initiated['phone'] ?? 'N/A'),
                      const SizedBox(height: 16),

                      _sectionTitle('👤 REQUESTED BY'),
                      _detailRow('Email', event['user_email'] ?? 'N/A'),
                      _detailRow('Name', _getDisplayNameFromEmail(event['user_email'] ?? '')),
                    ],
                  ),
                ),
              ),
              if (isPending && !adminApproved)
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
                            _updateStatus(event['id'], 'approved');
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Admin Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updateStatus(event['id'], 'rejected');
                          },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (adminApproved && !deptApproved)
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
                          '✅ Admin approved! Waiting for department approval.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _sectionTitle(String title) {
    return Padding(
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
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _facilityRow(String label, dynamic value) {
    bool selected = false;
    int count = 0;

    if (value is bool) {
      selected = value;
    } else if (value is Map) {
      selected = value['selected'] == true;
      count = value['count'] ?? 0;
    }

    if (!selected) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Text(
            count > 0 ? '$label ($count)' : label,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
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
                      _statCard('Rejected', _rejectedCount, Colors.red),
                      const SizedBox(width: 8),
                      _statCard('Total', _totalCount, const Color(0xFF1565C0)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(height: 8),
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

                // ✅ Excel Download Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportExcel,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        _isExporting
                            ? 'Generating Excel...'
                            : '📊 DOWNLOAD APPROVED EVENTS (EXCEL)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

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
                            final adminApproved = event['admin_approved'] == true;
                            final deptApproved = event['dept_approved'] == true;

                            return InkWell(
                              onTap: () => _showEventDetails(event),
                              borderRadius: BorderRadius.circular(12),
                              child: Card(
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
                                      if (event['department'] != null)
                                        Row(
                                          children: [
                                            const Icon(Icons.school, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Dept: ${event['department']}',
                                              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            event['venue'] ?? 'N/A',
                                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${event['booking_date'] ?? 'N/A'} | ${event['event_time_from'] ?? ''} - ${event['event_time_to'] ?? ''}',
                                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (adminApproved) _badge('✅ Admin Approved', Colors.green),
                                          if (deptApproved) _badge('✅ Dept Approved', Colors.green),
                                          if (adminApproved && !deptApproved) _badge('⏳ Waiting Dept', Colors.orange),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '👆 Tap to view details & take action',
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
      onSelected: (selected) => setState(() => _filter = value),
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
}