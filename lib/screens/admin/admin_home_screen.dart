import 'package:flutter/material.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/excel_service.dart';
import '../../widgets/clash_report_widget.dart';
import 'package:intl/intl.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  final _auth = SupabaseAuthService();
  final _adminService = AdminService();
  final _excelService = ExcelService();

  late TabController _tabController;

  Map<String, int> _stats = {'pending': 0, 'approved': 0, 'rejected': 0, 'today': 0};
  List<Map<String, dynamic>> _pendingEvents = [];
  List<Map<String, dynamic>> _allEvents = [];

  bool _loadingStats = true;
  bool _loadingPending = true;
  bool _loadingAll = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadStats();
    _loadPending();
    _loadAllEvents();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats = await _adminService.getStats();
      if (mounted) setState(() => _stats = stats);
    } catch (e) { _showError('Stats error: $e'); }
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final events = await _adminService.getPendingEvents();
      if (mounted) setState(() => _pendingEvents = events);
    } catch (e) { _showError('Pending events error: $e'); }
    if (mounted) setState(() => _loadingPending = false);
  }

  Future<void> _loadAllEvents() async {
    setState(() => _loadingAll = true);
    try {
      final events = await _adminService.getAllEvents();
      if (mounted) setState(() => _allEvents = events);
    } catch (e) { _showError('Events error: $e'); }
    if (mounted) setState(() => _loadingAll = false);
  }

  Future<void> _approveEvent(String eventId) async {
    try {
      await _adminService.approveEvent(eventId);
      _showSuccess('Event approved ✅');
      _loadAll();
    } catch (e) { _showError('Approve failed: $e'); }
  }

  Future<void> _rejectEvent(String eventId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to reject this event?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Room unavailable, date conflict...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.rejectEvent(eventId, reason: reasonController.text.trim());
        _showSuccess('Event rejected');
        _loadAll();
      } catch (e) { _showError('Reject failed: $e'); }
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      await _excelService.exportEventsToExcel();
      _showSuccess('Excel file downloaded ✅');
    } catch (e) { _showError('Export failed: $e'); }
    if (mounted) setState(() => _exporting = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Export button
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Export to Excel',
                  onPressed: _exportExcel,
                ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  const SizedBox(width: 6),
                  if (_stats['pending']! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_stats['pending']}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
            const Tab(text: 'All Events'),
            const Tab(text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildAllEventsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  // ─── Tab 1: Pending ──────────────────────────────────────────────────────
  Widget _buildPendingTab() {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No pending requests',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('All caught up! ✅',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingEvents.length,
        itemBuilder: (context, index) =>
            _buildPendingCard(_pendingEvents[index]),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> event) {
    final room = event['rooms'] as Map<String, dynamic>?;
    final user = event['users'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['event_name'] ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event['organization'] ?? '',
                        style: TextStyle(color: Colors.blue[700],
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                // Pending badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Text('PENDING',
                      style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 20),

            // ── Details grid ──
            _detailRow(Icons.person, 'Organizer', user?['name'] ?? 'Unknown'),
            const SizedBox(height: 6),
            _detailRow(Icons.calendar_today, 'Date', event['event_date'] ?? ''),
            const SizedBox(height: 6),
            _detailRow(
              Icons.access_time,
              'Time',
              '${AdminService.minutesToTime(event['start_time'] ?? 0)} → ${AdminService.minutesToTime(event['end_time'] ?? 0)}',
            ),
            const SizedBox(height: 6),
            _detailRow(
              Icons.meeting_room,
              'Room',
              '${room?['room_name'] ?? 'N/A'} — ${room?['building'] ?? ''}',
            ),
            const SizedBox(height: 6),
            _detailRow(
              Icons.people,
              'Crowd',
              '${event['expected_crowd'] ?? 0} people',
            ),

            if ((event['special_instructions'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              _detailRow(
                Icons.note,
                'Notes',
                event['special_instructions'],
              ),
            ],

            const Divider(height: 20),

            // ── AI Clash Detection ──
            const Row(
              children: [
                Icon(Icons.psychology, size: 16, color: Colors.purple),
                SizedBox(width: 6),
                Text('AI Clash Report',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ClashReportWidget(pendingEvent: event),

            const SizedBox(height: 16),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectEvent(event['id']),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _approveEvent(event['id']),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab 2: All Events ───────────────────────────────────────────────────
  Widget _buildAllEventsTab() {
    if (_loadingAll) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allEvents.isEmpty) {
      return const Center(child: Text('No events found'));
    }

    // Group by status
    final pending = _allEvents.where((e) => e['status'] == 'pending').toList();
    final approved = _allEvents.where((e) => e['status'] == 'approved').toList();
    final rejected = _allEvents.where((e) => e['status'] == 'rejected').toList();

    return RefreshIndicator(
      onRefresh: _loadAllEvents,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (approved.isNotEmpty) ...[
            _sectionHeader('Approved (${approved.length})', Colors.green),
            ...approved.map((e) => _buildEventTile(e, Colors.green)),
            const SizedBox(height: 16),
          ],
          if (pending.isNotEmpty) ...[
            _sectionHeader('Pending (${pending.length})', Colors.orange),
            ...pending.map((e) => _buildEventTile(e, Colors.orange)),
            const SizedBox(height: 16),
          ],
          if (rejected.isNotEmpty) ...[
            _sectionHeader('Rejected (${rejected.length})', Colors.red),
            ...rejected.map((e) => _buildEventTile(e, Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 4, height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event, Color statusColor) {
    final room = event['rooms'] as Map<String, dynamic>?;
    final user = event['users'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        leading: Container(
          width: 4,
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          event['event_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${user?['name'] ?? ''} • ${event['organization'] ?? ''}',
                style: const TextStyle(fontSize: 12)),
            Text(
              '${event['event_date']} • ${AdminService.minutesToTime(event['start_time'] ?? 0)} → ${AdminService.minutesToTime(event['end_time'] ?? 0)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '${room?['room_name'] ?? ''}, ${room?['building'] ?? ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            (event['status'] ?? '').toUpperCase(),
            style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ─── Tab 3: Stats ────────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _statCard('Pending', _stats['pending']!, Colors.orange,
                    Icons.hourglass_empty),
                _statCard('Approved', _stats['approved']!, Colors.green,
                    Icons.check_circle),
                _statCard('Rejected', _stats['rejected']!, Colors.red,
                    Icons.cancel),
                _statCard("Today's Events", _stats['today']!, Colors.blue,
                    Icons.today),
              ],
            ),

            const SizedBox(height: 28),

            // Export button (large)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportExcel,
                icon: _exporting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download),
                label: Text(_exporting
                    ? 'Exporting...'
                    : 'Export All Events to Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Total count
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('Total Events',
                      '${(_stats['pending']! + _stats['approved']! + _stats['rejected']!)}'),
                  _miniStat('Approval Rate',
                      _stats['approved']! + _stats['rejected']! > 0
                          ? '${((_stats['approved']! / (_stats['approved']! + _stats['rejected']!)) * 100).toStringAsFixed(0)}%'
                          : 'N/A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────
  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
        ),
      ],
    );
  }
}