import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/requisition_model.dart';
import '../../services/email_service.dart';
import '../../services/supabase_auth_service.dart';

class EditEventScreen extends StatefulWidget {
  final Map<String, dynamic> requisition;

  const EditEventScreen({super.key, required this.requisition});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _auth         = SupabaseAuthService();
  final _emailService = EmailService();
  bool _isSubmitting  = false;

  static const _blue = Color(0xFF1565C0);

  // ── Controllers ────────────────────────────────────────────────────────────
  late TextEditingController _purposeCtrl;
  late TextEditingController _strengthCtrl;
  late TextEditingController _instituteCtrl;
  late TextEditingController _furnitureCtrl;

  String    _selectedVenue = '';
  TimeOfDay _eventFrom     = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _eventTo       = const TimeOfDay(hour: 12, minute: 0);
  DateTime  _bookingDate   = DateTime.now().add(const Duration(days: 1));

  // Facilities
  bool _photography  = false;
  bool _videography  = false;
  bool _projector    = false;
  bool _laptopIT     = false;
  bool _podiumMike   = false;
  bool _cordlessMike = false;
  bool _collarMike   = false;
  bool _lamp         = false;
  bool _water        = false;
  bool _bouquet      = false;

  final _lampCntCtrl    = TextEditingController(text: '0');
  final _waterCntCtrl   = TextEditingController(text: '0');
  final _bouquetCntCtrl = TextEditingController(text: '0');

  final List<String> _venues = [
    'A Block Auditorium',
    'B Block Seminar Hall',
    'I Block Seminar Hall',
    'AT-15/16 Seminar Hall',
    'G Block Mandala Auditorium',
    'T Block Seminar Hall',
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final req = widget.requisition;

    _purposeCtrl   = TextEditingController(text: req['purpose']          ?? '');
    _strengthCtrl  = TextEditingController(text: req['expected_strength'] ?? '');
    _instituteCtrl = TextEditingController(
        text: req['institute_name'] ?? 'Manav Rachna International Institute of Research and Studies');
    _furnitureCtrl = TextEditingController(text: req['extra_furniture']   ?? '');
    _selectedVenue = req['venue'] ?? '';

    try {
      _bookingDate = DateTime.parse(req['booking_date']);
    } catch (_) {}

    try {
      final parts = (req['event_time_from'] as String).split(':');
      _eventFrom = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {}

    try {
      final parts = (req['event_time_to'] as String).split(':');
      _eventTo = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {}

    final fac = req['facilities'] as Map<String, dynamic>? ?? {};
    _photography  = _getBool(fac, 'photography');
    _videography  = _getBool(fac, 'videography');
    _projector    = _getBool(fac, 'projector');
    _laptopIT     = _getBool(fac, 'laptopIT');
    _podiumMike   = _getBool(fac, 'podiumMike');
    _cordlessMike = _getBool(fac, 'cordlessMike');
    _collarMike   = _getBool(fac, 'collarMike');
    _lamp         = _getBool(fac, 'lamp');
    _water        = _getBool(fac, 'water');
    _bouquet      = _getBool(fac, 'bouquet');

    _lampCntCtrl.text    = _getCount(fac, 'lamp').toString();
    _waterCntCtrl.text   = _getCount(fac, 'water').toString();
    _bouquetCntCtrl.text = _getCount(fac, 'bouquet').toString();
  }

  bool _getBool(Map<String, dynamic> fac, String key) {
    final val = fac[key];
    if (val == null)  return false;
    if (val is bool)  return val;
    if (val is Map)   return val['selected'] == true;
    return false;
  }

  int _getCount(Map<String, dynamic> fac, String key) {
    final val = fac[key];
    if (val is Map) return (val['count'] as num?)?.toInt() ?? 0;
    return 0;
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    _strengthCtrl.dispose();
    _instituteCtrl.dispose();
    _furnitureCtrl.dispose();
    _lampCntCtrl.dispose();
    _waterCntCtrl.dispose();
    _bouquetCntCtrl.dispose();
    super.dispose();
  }

  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmt(TimeOfDay t) {
    final p = t.hour >= 12 ? 'PM' : 'AM';
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $p';
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_purposeCtrl.text.trim().isEmpty) {
      _err('Please enter Purpose');
      return;
    }
    if (_selectedVenue.isEmpty) {
      _err('Please select a venue');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _auth.currentUserId;
      final reqId  = widget.requisition['id'] as String;

      final updatedFacilities = {
        'photography':  {'selected': _photography},
        'videography':  {'selected': _videography},
        'projector':    {'selected': _projector},
        'laptopIT':     {'selected': _laptopIT},
        'podiumMike':   {'selected': _podiumMike},
        'cordlessMike': {'selected': _cordlessMike},
        'collarMike':   {'selected': _collarMike},
        'lamp':         {'selected': _lamp,    'count': int.tryParse(_lampCntCtrl.text)    ?? 0},
        'water':        {'selected': _water,   'count': int.tryParse(_waterCntCtrl.text)   ?? 0},
        'bouquet':      {'selected': _bouquet, 'count': int.tryParse(_bouquetCntCtrl.text) ?? 0},
      };

      // ✅ Fixed: Supabase.instance.client
      await Supabase.instance.client
          .from('requisitions')
          .update({
            'venue':             _selectedVenue,
            'purpose':           _purposeCtrl.text.trim(),
            'expected_strength': _strengthCtrl.text.trim(),
            'institute_name':    _instituteCtrl.text.trim(),
            'extra_furniture':   _furnitureCtrl.text.trim(),
            'booking_date':      DateFormat('yyyy-MM-dd').format(_bookingDate),
            'event_time_from':   _timeStr(_eventFrom),
            'event_time_to':     _timeStr(_eventTo),
            'facilities':        updatedFacilities,
            'status':            'approved',
          })
          .eq('id', reqId);

      // ✅ Fixed: Supabase.instance.client
      final userRow = await Supabase.instance.client
          .from('users')
          .select('name, email')
          .eq('id', userId!)
          .maybeSingle();

      final userEmail = userRow?['email'] as String? ?? '';
      final userName  = userRow?['name']  as String? ?? 'Student';
      final date      = DateFormat('yyyy-MM-dd').format(_bookingDate);
      final time      = '${_timeStr(_eventFrom)} → ${_timeStr(_eventTo)}';

      if (_photography || _videography) {
        await _emailService.sendFacilityEmail(
          eventName:   _purposeCtrl.text.trim(),
          eventDate:   date,
          eventTime:   time,
          venue:       _selectedVenue,
          photography: _photography,
          videography: _videography,
          userName:    userName,
          userEmail:   userEmail,
        );
      }

      await _emailService.sendApprovalEmail(
        toEmail:   userEmail,
        userName:  userName,
        eventName: _purposeCtrl.text.trim(),
        eventDate: date,
        eventTime: time,
        venue:     _selectedVenue,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Event updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _err('Update failed: $e');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ── Cancel Event ──────────────────────────────────────────────────────────
  Future<void> _cancelEvent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Event'),
        content: const Text('Are you sure you want to cancel this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      // ✅ Fixed: Supabase.instance.client
      await Supabase.instance.client
          .from('requisitions')
          .update({'status': 'cancelled'})
          .eq('id', widget.requisition['id']);

      final userId = _auth.currentUserId;
      final userRow = await Supabase.instance.client
          .from('users')
          .select('name, email')
          .eq('id', userId!)
          .maybeSingle();

      final userEmail = userRow?['email'] as String? ?? '';
      final userName  = userRow?['name']  as String? ?? 'Student';
      final date      = widget.requisition['booking_date'] ?? 'N/A';
      final time      = '${widget.requisition['event_time_from'] ?? ''} → ${widget.requisition['event_time_to'] ?? ''}';
      final purpose   = widget.requisition['purpose'] ?? 'Untitled';
      final venue     = widget.requisition['venue'] ?? 'N/A';

      final fac = widget.requisition['facilities'] as Map<String, dynamic>? ?? {};
      final photography = _getBool(fac, 'photography');
      final videography = _getBool(fac, 'videography');

      await _emailService.sendCancellationEmail(
        studentEmail: userEmail,
        userName: userName,
        eventName: purpose,
        eventDate: date,
        eventTime: time,
        venue: venue,
        photography: photography,
        videography: videography,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event cancelled successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _err('Cancel failed: $e');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Requisition'),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Venue ──────────────────────────────────────────────────────
            _card(
              title: 'Venue Selection',
              icon: Icons.location_on,
              child: Column(
                children: _venues.map((v) {
                  final sel = _selectedVenue == v;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedVenue = v),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? _blue.withValues(alpha: 0.08)
                            : Colors.white,
                        border: Border.all(
                          color: sel ? _blue : Colors.grey.shade300,
                          width: sel ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: sel ? _blue : Colors.grey.shade500,
                                  width: 1.5),
                              borderRadius: BorderRadius.circular(3),
                              color: sel ? _blue : Colors.white,
                            ),
                            child: sel
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(v,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: sel ? _blue : Colors.black87)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Event Details ───────────────────────────────────────────────
            _card(
              title: 'Event Details',
              icon: Icons.event_note,
              child: Column(
                children: [
                  TextField(
                    controller: _instituteCtrl,
                    decoration: _dec('Name of Institute', Icons.school),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _purposeCtrl,
                    maxLines: 2,
                    decoration: _dec('Purpose *', Icons.note_alt),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _strengthCtrl,
                    decoration:
                        _dec('Expected Strength (e.g. 50-60)', Icons.people),
                  ),
                  const SizedBox(height: 12),
                  _tapField(
                    label: 'Booking Date',
                    value: DateFormat('dd/MM/yyyy').format(_bookingDate),
                    icon: Icons.calendar_month,
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _bookingDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (p != null) setState(() => _bookingDate = p);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _tapField(
                          label: 'Time From',
                          value: _fmt(_eventFrom),
                          icon: Icons.access_time,
                          onTap: () async {
                            final p = await showTimePicker(
                                context: context, initialTime: _eventFrom);
                            if (p != null) setState(() => _eventFrom = p);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _tapField(
                          label: 'Time To',
                          value: _fmt(_eventTo),
                          icon: Icons.access_time_filled,
                          onTap: () async {
                            final p = await showTimePicker(
                                context: context, initialTime: _eventTo);
                            if (p != null) setState(() => _eventTo = p);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Facilities ──────────────────────────────────────────────────
            _card(
              title: 'Required Facilities',
              icon: Icons.check_box,
              child: Column(
                children: [
                  _facRow('Lamp:', _lamp,
                      (v) => setState(() => _lamp = v!),
                      trailing: _lamp
                          ? _numField(_lampCntCtrl)
                          : const Text('In Numbers ___',
                              style: TextStyle(color: Colors.grey))),
                  const Divider(height: 1),
                  _facRow('Water Arrangements:', _water,
                      (v) => setState(() => _water = v!),
                      trailing: _water
                          ? _numField(_waterCntCtrl)
                          : const Text('In Numbers ___',
                              style: TextStyle(color: Colors.grey))),
                  const Divider(height: 1),
                  _facRow('Bouquet:', _bouquet,
                      (v) => setState(() => _bouquet = v!),
                      trailing: _bouquet
                          ? _numField(_bouquetCntCtrl)
                          : const Text('In Numbers ___',
                              style: TextStyle(color: Colors.grey))),
                  const Divider(height: 1),
                  _facRow('Still Photography:', _photography,
                      (v) => setState(() => _photography = v!),
                      trailing: const Text('MAIL 48 HRS PRIOR',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold))),
                  const Divider(height: 1),
                  _facRow('Videography:', _videography,
                      (v) => setState(() => _videography = v!),
                      trailing: const Text('MAIL 48 HRS PRIOR',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold))),
                  const Divider(height: 1),
                  _facRow('Projector for Presentation:', _projector,
                      (v) => setState(() => _projector = v!)),
                  if (_projector) ...[
                    _subFac('(a) Laptop with IT Person:', _laptopIT,
                        (v) => setState(() => _laptopIT = v!)),
                    _subFac('(b) Podium Mike:', _podiumMike,
                        (v) => setState(() => _podiumMike = v!)),
                    _subFac('(c) Cordless Mike:', _cordlessMike,
                        (v) => setState(() => _cordlessMike = v!)),
                    _subFac('(d) Collar Mike:', _collarMike,
                        (v) => setState(() => _collarMike = v!)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Extra Furniture ─────────────────────────────────────────────
            _card(
              title: 'Extra Furniture (If any)',
              icon: Icons.chair,
              child: TextField(
                controller: _furnitureCtrl,
                maxLines: 2,
                decoration: _dec('Specify extra furniture', Icons.edit_note),
              ),
            ),
            const SizedBox(height: 24),

            // ── Buttons ─────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _cancelEvent,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Event'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(
                        _isSubmitting ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────────
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
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
            Icon(icon, color: _blue, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _blue)),
          ]),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _tapField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: _blue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.edit, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _blue),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: _blue, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );

  Widget _facRow(String label, bool checked, ValueChanged<bool?> onChange,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChange(!checked),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                border: Border.all(
                    color: checked ? _blue : Colors.grey.shade500,
                    width: 1.5),
                borderRadius: BorderRadius.circular(3),
                color: checked ? _blue : Colors.white,
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 15)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              flex: 2,
              child: Text(label, style: const TextStyle(fontSize: 14))),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Expanded(flex: 2, child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _numField(TextEditingController ctrl) => SizedBox(
        height: 38,
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      );

  Widget _subFac(String label, bool value, ValueChanged<bool?> onChange) =>
      Padding(
        padding: const EdgeInsets.only(left: 32, bottom: 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => onChange(!value),
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: value ? _blue : Colors.grey.shade500),
                  borderRadius: BorderRadius.circular(3),
                  color: value ? _blue : Colors.white,
                ),
                child: value
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}