import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/step_indicator.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _eventService = EventService();
  final _auth = SupabaseAuthService();

  int _currentStep = 0;

  // Step 1 fields
  final _eventNameController = TextEditingController();
  final _crowdController = TextEditingController();
  String _selectedOrg = 'IEEE';

  final List<String> _organizations = [
    'IEEE', 'CSI', 'Dance Club', 'Music Club',
    'Sports Club', 'Drama Club', 'Coding Club', 'Other',
  ];

  // Step 2 fields
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  // Step 3 fields
  List<Map<String, dynamic>> _availableRooms = [];
  Map<String, dynamic>? _selectedRoom;
  bool _loadingRooms = false;

  // Step 4 fields
  final _instructionsController = TextEditingController();
  bool _isSubmitting = false;

  // Convert TimeOfDay to minutes from midnight
  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  // Convert minutes to readable string
  String _minutesToString(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${displayH.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _crowdController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  // ─── Step 1 Validation ────────────────────────────────────────────────────
  bool _validateStep1() {
    if (_eventNameController.text.trim().isEmpty) {
      _showError('Please enter event name');
      return false;
    }
    if (_crowdController.text.trim().isEmpty) {
      _showError('Please enter expected crowd');
      return false;
    }
    if (int.tryParse(_crowdController.text.trim()) == null) {
      _showError('Expected crowd must be a number');
      return false;
    }
    return true;
  }

  // ─── Step 2 Validation ────────────────────────────────────────────────────
  bool _validateStep2() {
    if (_toMinutes(_endTime) <= _toMinutes(_startTime)) {
      _showError('End time must be after start time');
      return false;
    }
    if (_selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      _showError('Please select a future date');
      return false;
    }
    return true;
  }

  // ─── Load Rooms ───────────────────────────────────────────────────────────
  Future<void> _loadRooms() async {
    setState(() => _loadingRooms = true);
    try {
      final crowd = int.parse(_crowdController.text.trim());
      final rooms = await _eventService.getAvailableRooms(crowd);
      setState(() => _availableRooms = rooms);
      if (rooms.isEmpty) {
        _showError('No rooms available for $crowd people. Try a smaller crowd size.');
      }
    } catch (e) {
      _showError('Error loading rooms: $e');
    }
    setState(() => _loadingRooms = false);
  }

  // ─── Submit Event ─────────────────────────────────────────────────────────
  Future<void> _submitEvent() async {
    setState(() => _isSubmitting = true);
    try {
      final userId = _auth.currentUserId;
      if (userId == null) throw Exception('Not logged in');
      if (_selectedRoom == null) throw Exception('No room selected');

      final event = EventModel(
        id: '',
        organizerId: userId,
        eventName: _eventNameController.text.trim(),
        organization: _selectedOrg,
        date: _selectedDate,
        startTime: _toMinutes(_startTime),
        endTime: _toMinutes(_endTime),
        roomId: _selectedRoom!['id'],
        expectedCrowd: int.parse(_crowdController.text.trim()),
        status: 'pending',
        specialInstructions: _instructionsController.text.trim(),
      );

      await _eventService.createEvent(event);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Event request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // true = refresh parent
    } catch (e) {
      _showError('Submit failed: $e');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _nextStep() async {
    if (_currentStep == 0 && !_validateStep1()) return;
    if (_currentStep == 1 && !_validateStep2()) return;
    if (_currentStep == 1) await _loadRooms(); // load rooms before step 3
    if (_currentStep == 2 && _selectedRoom == null) {
      _showError('Please select a room');
      return;
    }
    if (_currentStep < 3) setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Event Request'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Step indicator bar
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: StepIndicator(currentStep: _currentStep, totalSteps: 4),
          ),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentStep(),
              ),
            ),
          ),

          // Bottom navigation buttons
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      default: return const SizedBox();
    }
  }

  // ─── Step 1: Event Basics ─────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Event Basics', Icons.event_note),
        const SizedBox(height: 24),
        TextField(
          controller: _eventNameController,
          decoration: const InputDecoration(
            labelText: 'Event Name *',
            hintText: 'e.g. Annual Tech Fest 2025',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.title),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          value: _selectedOrg,
          decoration: const InputDecoration(
            labelText: 'Organization *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.group),
          ),
          items: _organizations
              .map((org) => DropdownMenuItem(value: org, child: Text(org)))
              .toList(),
          onChanged: (val) => setState(() => _selectedOrg = val!),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _crowdController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Expected Crowd *',
            hintText: 'e.g. 150',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
            suffixText: 'people',
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Date & Time ──────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Date & Time', Icons.calendar_today),
        const SizedBox(height: 24),

        // Date picker card
        _infoCard(
          label: 'Event Date',
          value: DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
          icon: Icons.calendar_month,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
        ),
        const SizedBox(height: 16),

        // Start time picker card
        _infoCard(
          label: 'Start Time',
          value: _startTime.format(context),
          icon: Icons.access_time,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _startTime,
            );
            if (picked != null) setState(() => _startTime = picked);
          },
        ),
        const SizedBox(height: 16),

        // End time picker card
        _infoCard(
          label: 'End Time',
          value: _endTime.format(context),
          icon: Icons.access_time_filled,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _endTime,
            );
            if (picked != null) setState(() => _endTime = picked);
          },
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duration: ${_getDuration()}',
                  style: const TextStyle(color: Colors.blue, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getDuration() {
    final start = _toMinutes(_startTime);
    final end = _toMinutes(_endTime);
    if (end <= start) return 'Invalid (end must be after start)';
    final diff = end - start;
    final h = diff ~/ 60;
    final m = diff % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  // ─── Step 3: Room Selection ───────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Select Room', Icons.meeting_room),
        const SizedBox(height: 8),
        Text(
          'Showing rooms for ${_crowdController.text} people',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 20),

        if (_loadingRooms)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Finding available rooms...'),
                ],
              ),
            ),
          )
        else if (_availableRooms.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.meeting_room_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('No rooms available', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Try reducing expected crowd',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ...(_availableRooms.map((room) => _roomCard(room)).toList()),
      ],
    );
  }

  Widget _roomCard(Map<String, dynamic> room) {
    final isSelected = _selectedRoom?['id'] == room['id'];
    final amenities = List<String>.from(room['amenities'] ?? []);

    return GestureDetector(
      onTap: () => setState(() => _selectedRoom = room),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Room icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.meeting_room,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),

            // Room details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room['room_name'] ?? 'Room',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${room['building'] ?? ''} • Floor ${room['floor'] ?? ''}  • Room ${room['room_number'] ?? ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Capacity: ${room['capacity']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: amenities
                          .map((a) => _amenityChip(a))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Selected indicator
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _amenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.green[700]),
      ),
    );
  }

  // ─── Step 4: Review & Submit ──────────────────────────────────────────────
  Widget _buildStep4() {
    return Column(
      key: const ValueKey('step4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Review & Submit', Icons.fact_check),
        const SizedBox(height: 20),

        // Summary card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _summaryRow(Icons.event, 'Event Name', _eventNameController.text.trim()),
              _divider(),
              _summaryRow(Icons.group, 'Organization', _selectedOrg),
              _divider(),
              _summaryRow(Icons.calendar_today, 'Date',
                  DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate)),
              _divider(),
              _summaryRow(Icons.access_time, 'Time',
                  '${_startTime.format(context)} → ${_endTime.format(context)} (${_getDuration()})'),
              _divider(),
              _summaryRow(Icons.meeting_room, 'Room',
                  _selectedRoom?['room_name'] ?? '-'),
              _divider(),
              _summaryRow(Icons.location_on, 'Location',
                  '${_selectedRoom?['building'] ?? ''}, Floor ${_selectedRoom?['floor'] ?? ''}'),
              _divider(),
              _summaryRow(Icons.people, 'Expected Crowd',
                  '${_crowdController.text} people'),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Special instructions
        TextField(
          controller: _instructionsController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Special Instructions (optional)',
            hintText: 'e.g. Need microphone setup, require chairs arrangement...',
            border: OutlineInputBorder(),
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.note_add),
            ),
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your request will be sent to admin for approval.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade100);

  // ─── Bottom Buttons ───────────────────────────────────────────────────────
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button (hidden on step 1)
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),

          // Next / Submit button
          Expanded(
            flex: 2,
            child: _currentStep < 3
                ? ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitEvent,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request'),
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

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _stepTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _infoCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.edit, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }
}