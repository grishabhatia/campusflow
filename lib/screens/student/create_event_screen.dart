import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/requisition_model.dart';
import '../../models/clash_model.dart';
import '../../services/requisition_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/auto_approval_service.dart';
import '../../services/email_service.dart';
import '../../widgets/step_indicator.dart';
import '../../widgets/clash_popup_dialog.dart';
import '../../widgets/approval_popup_dialog.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _reqService = RequisitionService();
  final _auth       = SupabaseAuthService();
  final _emailService = EmailService();
  int  _currentStep = 0;
  bool _isSubmitting = false;

  static const _blue = Color(0xFF1565C0);

  // ── Step 1: Venue ──────────────────────────────────────────────────────────
  String _selectedVenue = '';
  final List<String> _venues = [
    'A Block Auditorium',
    'B Block Seminar Hall',
    'I Block Seminar Hall',
    'AT-15/16 Seminar Hall',
    'G Block Mandala Auditorium',
    'T Block Seminar Hall',
  ];

  // ── Step 2: Booking + Slots ────────────────────────────────────────────────
  DateTime  _bookingDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _bookingTime = const TimeOfDay(hour: 11, minute: 0);
  final List<SlotModel> _slots = [];

  // ── Step 3: Event Details ──────────────────────────────────────────────────
  final _instituteCtrl = TextEditingController(text: 'Manav Rachna International Institute of Research and Studies');
  final _purposeCtrl   = TextEditingController();
  final _strengthCtrl  = TextEditingController();
  TimeOfDay _eventFrom = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _eventTo   = const TimeOfDay(hour: 12, minute: 0);

  // ── Step 4: Facilities ─────────────────────────────────────────────────────
  final FacilityModel _fac = FacilityModel();

  final _lampCntCtrl    = TextEditingController(text: '0');
  final _waterCntCtrl   = TextEditingController(text: '0');
  final _bouquetCntCtrl = TextEditingController(text: '0');
  final _photoFromCtrl  = TextEditingController();
  final _photoToCtrl    = TextEditingController();
  final _videoFromCtrl  = TextEditingController();
  final _videoToCtrl    = TextEditingController();
  final _furnitureCtrl  = TextEditingController();

  // ── Step 5: Signatures (Only Initiated By) ──────────────────────────────
  final SignatureModel _sigs = SignatureModel();

  final _initNameCtrl = TextEditingController();
  final _initSignCtrl = TextEditingController();
  final _initMobCtrl  = TextEditingController();

  @override
  void dispose() {
    _instituteCtrl.dispose(); _purposeCtrl.dispose(); _strengthCtrl.dispose();
    _lampCntCtrl.dispose(); _waterCntCtrl.dispose(); _bouquetCntCtrl.dispose();
    _photoFromCtrl.dispose(); _photoToCtrl.dispose();
    _videoFromCtrl.dispose(); _videoToCtrl.dispose();
    _furnitureCtrl.dispose();
    _initNameCtrl.dispose(); _initSignCtrl.dispose(); _initMobCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmt(TimeOfDay t) {
    final p = t.hour >= 12 ? 'PM' : 'AM';
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $p';
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    switch (_currentStep) {
      case 0:
        if (_selectedVenue.isEmpty) {
          _err('Please tick your venue choice');
          return false;
        }
      case 1:
        if (_slots.isEmpty) {
          _err('Please add at least one Required On slot');
          return false;
        }
      case 2:
        if (_purposeCtrl.text.trim().isEmpty) {
          _err('Please enter Purpose');
          return false;
        }
        if (_strengthCtrl.text.trim().isEmpty) {
          _err('Please enter Expected Strength');
          return false;
        }
      case 3:
        break;
      case 4:
        if (_initNameCtrl.text.trim().isEmpty) {
          _err('Please enter Initiated By name');
          return false;
        }
    }
    return true;
  }

  void _next() {
    if (_validate() && _currentStep < 4) setState(() => _currentStep++);
  }

  void _prev() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final userId = _auth.currentUserId;
      if (userId == null) throw Exception('Not logged in');

      // Sync facility controllers into model
      _fac.lampCount    = int.tryParse(_lampCntCtrl.text)    ?? 0;
      _fac.waterCount   = int.tryParse(_waterCntCtrl.text)   ?? 0;
      _fac.bouquetCount = int.tryParse(_bouquetCntCtrl.text) ?? 0;
      _fac.videoFrom    = _videoFromCtrl.text.trim();
      _fac.videoTo      = _videoToCtrl.text.trim();

      // Sync signature controllers into model
      _sigs.initiatedName   = _initNameCtrl.text.trim();
      _sigs.initiatedSign   = _initSignCtrl.text.trim();
      _sigs.initiatedPhone  = _initMobCtrl.text.trim();

      final req = RequisitionModel(
        userId:           userId,
        venue:            _selectedVenue,
        bookingDate:      DateFormat('yyyy-MM-dd').format(_bookingDate),
        bookingTime:      _timeStr(_bookingTime),
        slots:            [], // Empty for now — will update after save
        instituteName:    _instituteCtrl.text.trim(),
        eventTimeFrom:    _timeStr(_eventFrom),
        eventTimeTo:      _timeStr(_eventTo),
        purpose:          _purposeCtrl.text.trim(),
        expectedStrength: _strengthCtrl.text.trim(),
        facilities:       _fac,
        extraFurniture:   _furnitureCtrl.text.trim(),
        signatures:       _sigs,
      );

      // ── 1. Save to Supabase ──────────────────────────────────────────────
      await _reqService.submitRequisition(req);

      // ── 2. Fetch the just-created row ────────────────────────────────────
      final created = await Supabase.instance.client
          .from('requisitions')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      // ── 3. Update slots with actual event time ──────────────────────────
      await Supabase.instance.client
          .from('requisitions')
          .update({
            'slots': [
              {
                'date': req.bookingDate,
                'from': req.eventTimeFrom,
                'to': req.eventTimeTo,
              }
            ]
          })
          .eq('id', created['id']);

      // ── 4. Fetch user info for emails ────────────────────────────────────
      final userRow = await Supabase.instance.client
          .from('users')
          .select('name, email')
          .eq('id', userId)
          .maybeSingle();

      final userEmail = userRow?['email'] as String? ?? '';
      final userName  = userRow?['name']  as String? ?? 'Student';

      // ── 5. Run Auto-Approval ─────────────────────────────────────────────
      final autoApproval = AutoApprovalService();
      final result = await autoApproval.processRequisition(
        requisition: created,
        userEmail:   userEmail,
        userName:    userName,
      );

      if (!mounted) return;

      final hasClash = result['hasClash'] as bool? ?? false;
      final clashesRaw = result['clashes'] as List? ?? [];

      // ✅ Convert raw list to ClashModel list
      final clashes = clashesRaw.map((c) {
        if (c is ClashModel) return c;
        return ClashModel.fromMap(c as Map<String, dynamic>);
      }).toList();

      if (hasClash) {
        await _emailService.sendClashEmail(
          toEmail: userEmail,
          userName: userName,
          eventName: req.purpose,
          eventDate: req.bookingDate,
          eventTime: '${req.eventTimeFrom} → ${req.eventTimeTo}',
          venue: req.venue,
          clashes: clashes.map((c) => c.toMap()).toList(),
        );

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ClashPopupDialog(
            eventName: req.purpose,
            roomName: req.venue,
            eventDate: req.bookingDate,
            startTime: req.eventTimeFrom,
            endTime: req.eventTimeTo,
            clashes: clashes.map((c) => c.toMap()).toList(),
          ),
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ApprovalPopupDialog(
            eventName: req.purpose,
            venue:     req.venue,
            date:      req.bookingDate,
            time:      '${req.eventTimeFrom} → ${req.eventTimeTo}',
            aiScore:   result['score']  as int?    ?? 0,
            aiReason:  result['reason'] as String? ?? '',
          ),
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      _err('Submit failed: $e');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ── Add Slot Dialog ────────────────────────────────────────────────────────
  Future<void> _addSlot() async {
    DateTime  date = DateTime.now().add(const Duration(days: 1));
    TimeOfDay from = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay to   = const TimeOfDay(hour: 12, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add Required On Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTile(ctx, Icons.calendar_today, 'Date',
                  DateFormat('dd/MM/yyyy').format(date), () async {
                final p = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (p != null) setS(() => date = p);
              }),
              _dialogTile(ctx, Icons.access_time, 'From', _fmt(from), () async {
                final p = await showTimePicker(context: ctx, initialTime: from);
                if (p != null) setS(() => from = p);
              }),
              _dialogTile(ctx, Icons.access_time_filled, 'To', _fmt(to), () async {
                final p = await showTimePicker(context: ctx, initialTime: to);
                if (p != null) setS(() => to = p);
              }),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _slots.add(SlotModel(
                    date: DateFormat('dd/MM/yyyy').format(date),
                    from: _fmt(from),
                    to:   _fmt(to),
                  ));
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTile(BuildContext ctx, IconData icon, String label,
      String value, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: _blue),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      onTap: onTap,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Requisition Form'),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _blue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                const Text(
                  'MANAV RACHNA INTERNATIONAL INSTITUTE OF RESEARCH AND STUDIES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'REQUISITION FORM FOR EVENTS /\nAUDITORIUM & SEMINAR HALL',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                StepIndicator(currentStep: _currentStep, totalSteps: 5),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildStep(),
              ),
            ),
          ),
          _bottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0: return _step1Venue();
      case 1: return _step2Booking();
      case 2: return _step3Details();
      case 3: return _step4Facilities();
      case 4: return _step5Signatures();
      default: return const SizedBox();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Venue Selection
  // ══════════════════════════════════════════════════════════════════════════
  Widget _step1Venue() {
    return _card(
      key: const ValueKey('step1'),
      title: 'Venue Selection',
      subtitle: '(Please Tick Your Choice)',
      icon: Icons.location_on,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _venueOption('A Block Auditorium'),
                    _venueOption('B Block Seminar Hall'),
                    _venueOption('I Block Seminar Hall'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _venueOption('AT-15/16 Seminar Hall'),
                    _venueOption('G Block Mandala Auditorium'),
                    _venueOption('T Block Seminar Hall'),
                  ],
                ),
              ),
            ],
          ),
          if (_selectedVenue.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: $_selectedVenue',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _venueOption(String venue) {
    final selected = _selectedVenue == venue;
    return GestureDetector(
      onTap: () => setState(() => _selectedVenue = venue),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _blue.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? _blue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: selected ? _blue : Colors.grey.shade500, width: 1.5),
                borderRadius: BorderRadius.circular(3),
                color: selected ? _blue : Colors.white,
              ),
              child: selected ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                venue,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? _blue : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Booking Date/Time + Required On Slots
  // ══════════════════════════════════════════════════════════════════════════
  Widget _step2Booking() {
    return Column(
      key: const ValueKey('step2'),
      children: [
        _card(
          title: 'Booking Details',
          icon: Icons.book_online,
          child: Row(
            children: [
              Expanded(
                child: _tapField(
                  label: 'Booking Date:',
                  value: DateFormat('dd/MM/yyyy').format(_bookingDate),
                  icon: Icons.calendar_month,
                  onTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _bookingDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (p != null) setState(() => _bookingDate = p);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tapField(
                  label: 'Booking Time:',
                  value: _fmt(_bookingTime),
                  icon: Icons.access_time,
                  onTap: () async {
                    final p = await showTimePicker(context: context, initialTime: _bookingTime);
                    if (p != null) setState(() => _bookingTime = p);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Required On:',
          subtitle: 'Add all required date & time slots',
          icon: Icons.date_range,
          child: Column(
            children: [
              if (_slots.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No slots added. Tap below to add.',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ..._slots.asMap().entries.map((e) {
                final i = e.key;
                final slot = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${slot.date}  (${slot.from} – ${slot.to})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _slots.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addSlot,
                  icon: const Icon(Icons.add),
                  label: const Text('ADD REQUIRED ON SLOT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — Event Details
  // ══════════════════════════════════════════════════════════════════════════
  Widget _step3Details() {
    return _card(
      key: const ValueKey('step3'),
      title: 'Event Details',
      icon: Icons.event_note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _instituteCtrl,
            decoration: _dec('Name of Institute:', Icons.school),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _tapField(
                  label: 'Time From:',
                  value: _fmt(_eventFrom),
                  icon: Icons.access_time,
                  onTap: () async {
                    final p = await showTimePicker(context: context, initialTime: _eventFrom);
                    if (p != null) setState(() => _eventFrom = p);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('To:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: _tapField(
                  label: 'Time To:',
                  value: _fmt(_eventTo),
                  icon: Icons.access_time_filled,
                  onTap: () async {
                    final p = await showTimePicker(context: context, initialTime: _eventTo);
                    if (p != null) setState(() => _eventTo = p);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _purposeCtrl,
            maxLines: 2,
            decoration: _dec('Purpose: *', Icons.note_alt),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _strengthCtrl,
            decoration: _dec('Expected Strength: * (e.g. 50-60)', Icons.people),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Required Facilities
  // ══════════════════════════════════════════════════════════════════════════
  Widget _step4Facilities() {
    return Column(
      key: const ValueKey('step4'),
      children: [
        _card(
          title: 'Required Facilities:',
          subtitle: '(Please Tick)',
          icon: Icons.check_box,
          child: Column(
            children: [
              _facilityRow(
                label: 'Lamp:',
                checked: _fac.lamp,
                onChanged: (v) => setState(() => _fac.lamp = v!),
                trailing: _fac.lamp
                    ? _numberField('In Numbers', _lampCntCtrl)
                    : const Text('In Numbers ___', style: TextStyle(color: Colors.grey)),
              ),
              const Divider(height: 1),
              _facilityRow(
                label: 'Water Arrangements:',
                checked: _fac.water,
                onChanged: (v) => setState(() => _fac.water = v!),
                trailing: _fac.water
                    ? _numberField('In Numbers', _waterCntCtrl)
                    : const Text('In Numbers ___', style: TextStyle(color: Colors.grey)),
              ),
              const Divider(height: 1),
              _facilityRow(
                label: 'Bouquet:',
                checked: _fac.bouquet,
                onChanged: (v) => setState(() => _fac.bouquet = v!),
                trailing: _fac.bouquet
                    ? _numberField('In Numbers', _bouquetCntCtrl)
                    : const Text('In Numbers ___', style: TextStyle(color: Colors.grey)),
              ),
              const Divider(height: 1),
              _facilityRow(
                label: 'Still Photography:',
                checked: _fac.photography,
                onChanged: (v) => setState(() => _fac.photography = v!),
                trailing: const Text(
                  'MAIL 48 HOURS\nPRIOR TO EVENT',
                  style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              if (_fac.photography) _timeFromToRow('Photography Time:', _photoFromCtrl, _photoToCtrl),
              const Divider(height: 1),
              _facilityRow(
                label: 'Videography:',
                checked: _fac.videography,
                onChanged: (v) => setState(() => _fac.videography = v!),
                trailing: const Text(
                  'MAIL 48 HOURS\nPRIOR TO EVENT',
                  style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              if (_fac.videography) _timeFromToRow('Videography Time:', _videoFromCtrl, _videoToCtrl),
              const Divider(height: 1),
              _facilityRow(
                label: 'Projector for\nPresentation:',
                checked: _fac.projector,
                onChanged: (v) => setState(() => _fac.projector = v!),
              ),
              if (_fac.projector) ...[
                _subFacility('(a) Laptop with IT Person:', _fac.laptopIT, (v) => setState(() => _fac.laptopIT = v!)),
                _subFacility('(b) Podium Mike:', _fac.podiumMike, (v) => setState(() => _fac.podiumMike = v!)),
                _subFacility('(c) Cordless Mike:', _fac.cordlessMike, (v) => setState(() => _fac.cordlessMike = v!)),
                _subFacility('(d) Collar Mike:', _fac.collarMike, (v) => setState(() => _fac.collarMike = v!)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Extra Furniture (If any):',
          icon: Icons.chair,
          child: TextField(
            controller: _furnitureCtrl,
            maxLines: 2,
            decoration: _dec('Specify extra furniture', Icons.edit_note),
          ),
        ),
      ],
    );
  }

  Widget _facilityRow({
    required String label,
    required bool checked,
    required ValueChanged<bool?> onChanged,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged(!checked),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(color: checked ? _blue : Colors.grey.shade500, width: 1.5),
                borderRadius: BorderRadius.circular(3),
                color: checked ? _blue : Colors.white,
              ),
              child: checked ? const Icon(Icons.check, color: Colors.white, size: 15) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 14))),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Expanded(flex: 2, child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _numberField(String hint, TextEditingController ctrl) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
    );
  }

  Widget _timeFromToRow(String label, TextEditingController fromCtrl,
      TextEditingController toCtrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 4, 0, 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: fromCtrl,
              decoration: const InputDecoration(
                hintText: 'From',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('To:', style: TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: TextField(
              controller: toCtrl,
              decoration: const InputDecoration(
                hintText: 'To',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subFacility(
      String label, bool value, ValueChanged<bool?> onChange) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChange(!value),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: value ? _blue : Colors.grey.shade500),
                borderRadius: BorderRadius.circular(3),
                color: value ? _blue : Colors.white,
              ),
              child: value ? const Icon(Icons.check, color: Colors.white, size: 13) : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5 — Signatures (Only Initiated By)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _step5Signatures() {
    return Column(
      key: const ValueKey('step5'),
      children: [
        _sigBlock(
          title: 'Initiated By\n(Department) *',
          nameCtrl: _initNameCtrl,
          signCtrl: _initSignCtrl,
          mobCtrl: _initMobCtrl,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NOTE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                'Use this Requisition form only for Events/Meeting Room Bookings. '
                'Any format other than this prescribed format will not be acceptable.',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 6),
              Text('Please mail the filled form at:', style: TextStyle(fontSize: 12)),
              Text(
                'manager.admin@mrvpl.in',
                style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
              ),
              Text(
                '& CC to virender.events@mriu.edu.in',
                style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'For any assistance please contact:\n+91-8800734239 & Extn. 8217',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sigBlock({
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController signCtrl,
    TextEditingController? mobCtrl,
  }) {
    return _card(
      title: title,
      icon: Icons.draw,
      child: Column(
        children: [
          TextField(controller: nameCtrl, decoration: _dec('Name', Icons.person)),
          const SizedBox(height: 10),
          TextField(controller: signCtrl, decoration: _dec('Sign / Designation', Icons.badge)),
          if (mobCtrl != null) ...[
            const SizedBox(height: 10),
            TextField(
              controller: mobCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec('Mob.:', Icons.phone),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bottom Buttons ──────────────────────────────────────────────────────────
  Widget _bottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _currentStep < 4
                ? ElevatedButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Requisition'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Reusable card / field widgets ──────────────────────────────────────────
  Widget _card({
    Key? key,
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _blue)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
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
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.edit, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _blue),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: _blue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}