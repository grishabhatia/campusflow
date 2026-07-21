import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/requisition_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/status_badge.dart';

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> requisition;

  const EventDetailScreen({super.key, required this.requisition});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _reqService = RequisitionService();
  final _auth = SupabaseAuthService();
  bool _cancelling = false;

  Map<String, dynamic> get req => widget.requisition;

  Future<void> _cancelRequisition() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Requisition'),
        content: const Text(
            'Are you sure you want to cancel this event request? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, Keep It')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _cancelling = true);
      try {
        await _reqService.updateStatus(req['id'], 'cancelled');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Requisition cancelled'),
              backgroundColor: Colors.orange),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = req['status'] ?? 'pending';
    final slots =
        List<Map<String, dynamic>>.from(req['slots'] ?? []);
    final facilities =
        req['facilities'] as Map<String, dynamic>? ?? {};
    final signatures =
        req['signatures'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Requisition Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: req['id'] ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.statusColor(status).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.statusColor(status).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    status == 'approved'
                        ? Icons.check_circle
                        : status == 'rejected'
                            ? Icons.cancel
                            : Icons.hourglass_empty,
                    color: AppColors.statusColor(status),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(status: status, large: true),
                        const SizedBox(height: 4),
                        Text(
                          status == 'approved'
                              ? 'Your event has been approved!'
                              : status == 'rejected'
                                  ? 'Your request was not approved.'
                                  : 'Waiting for admin approval...',
                          style: TextStyle(
                              color: AppColors.statusColor(status),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Venue & Purpose ──
            _section(
              title: 'Event Information',
              icon: Icons.event,
              children: [
                _row('Venue', req['venue'] ?? '', Icons.location_on),
                _row('Purpose', req['purpose'] ?? '', Icons.description),
                _row('Institute', req['institute_name'] ?? '', Icons.school),
                _row('Expected Strength',
                    req['expected_strength'] ?? '', Icons.people),
                _row('Booking Date', req['booking_date'] ?? '',
                    Icons.calendar_today),
                _row('Booking Time', req['booking_time'] ?? '',
                    Icons.access_time),
                _row(
                  'Event Time',
                  '${req['event_time_from'] ?? ''} → ${req['event_time_to'] ?? ''}',
                  Icons.schedule,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Slots ──
            if (slots.isNotEmpty) ...[
              _section(
                title: 'Required Date-Time Slots',
                icon: Icons.date_range,
                children: slots
                    .asMap()
                    .entries
                    .map((e) => _row(
                          'Slot ${e.key + 1}',
                          '${e.value['date']}  ${e.value['from']} → ${e.value['to']}',
                          Icons.event_available,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // ── Facilities ──
            if (facilities.isNotEmpty) ...[
              _section(
                title: 'Requested Facilities',
                icon: Icons.check_box,
                children: [_buildFacilitiesSummary(facilities)],
              ),
              const SizedBox(height: 12),
            ],

            // ── Extra Furniture ──
            if ((req['extra_furniture'] ?? '').isNotEmpty) ...[
              _section(
                title: 'Extra Furniture',
                icon: Icons.chair,
                children: [
                  _row('Details', req['extra_furniture'], Icons.info_outline),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── Approval Chain ──
            _section(
              title: 'Approval Chain',
              icon: Icons.approval,
              children: [
                _signatureRow('Initiated By',
                    signatures['initiated'] as Map<String, dynamic>?),
                _signatureRow('Forwarded By',
                    signatures['forwarded'] as Map<String, dynamic>?),
                _signatureRow('Recommended By',
                    signatures['recommended'] as Map<String, dynamic>?),
                _signatureRow('Approved By',
                    signatures['approved'] as Map<String, dynamic>?),
              ],
            ),
            const SizedBox(height: 24),

            // ── Cancel Button (only for pending) ──
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelRequisition,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: Text(
                    _cancelling ? 'Cancelling...' : 'Cancel Request',
                    style: const TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ]),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _signatureRow(String role, Map<String, dynamic>? sig) {
    if (sig == null || (sig['name'] ?? '').isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.remove_circle_outline,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('$role: Not filled',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.draw, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
              width: 110,
              child: Text(role,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sig['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if ((sig['sign'] ?? '').isNotEmpty)
                  Text(sig['sign'] ?? '',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                if ((sig['phone'] ?? '').isNotEmpty)
                  Text(sig['phone'] ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesSummary(Map<String, dynamic> f) {
    final items = <String>[];
    if (f['lamp']?['selected'] == true)
      items.add('💡 Lamp × ${f['lamp']['count']}');
    if (f['water']?['selected'] == true)
      items.add('💧 Water × ${f['water']['count']}');
    if (f['bouquet']?['selected'] == true)
      items.add('💐 Bouquet × ${f['bouquet']['count']}');
    if (f['photography']?['selected'] == true)
      items.add('📸 Photography');
    if (f['videography']?['selected'] == true)
      items.add('🎥 Videography');
    if (f['projector']?['selected'] == true)
      items.add('📽️ Projector');
    if (f['laptopIT']?['selected'] == true)
      items.add('💻 Laptop + IT Person');
    if (f['podiumMike']?['selected'] == true)
      items.add('🎤 Podium Mike');
    if (f['cordlessMike']?['selected'] == true)
      items.add('🎤 Cordless Mike');
    if (f['collarMike']?['selected'] == true)
      items.add('🎤 Collar Mike');

    if (items.isEmpty) {
      return const Text('No facilities requested',
          style: TextStyle(color: AppColors.textSecondary));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(item,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.primary)),
              ))
          .toList(),
    );
  }
}