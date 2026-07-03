class EventModel {
  final String id;
  final String organizerId;
  final String eventName;
  final String organization;
  final DateTime date;
  final int startTime; // Minutes from midnight
  final int endTime;   // Minutes from midnight
  final String roomId;
  final int expectedCrowd;
  final List<String> resources;
  final String status;
  final String specialInstructions;

  EventModel({
    required this.id,
    required this.organizerId,
    required this.eventName,
    required this.organization,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.expectedCrowd,
    this.resources = const [],
    this.status = 'pending',
    this.specialInstructions = '',
  });

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] ?? '',
      organizerId: map['organizer_id'] ?? '',
      eventName: map['event_name'] ?? '',
      organization: map['organization'] ?? '',
      date: DateTime.parse(map['event_date']),
      startTime: map['start_time'] ?? 0,
      endTime: map['end_time'] ?? 0,
      roomId: map['room_id'] ?? '',
      expectedCrowd: map['expected_crowd'] ?? 0,
      resources: List<String>.from(map['resources'] ?? []),
      status: map['status'] ?? 'pending',
      specialInstructions: map['special_instructions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizer_id': organizerId,
      'event_name': eventName,
      'organization': organization,
      'event_date': date.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'room_id': roomId,
      'expected_crowd': expectedCrowd,
      'resources': resources,
      'status': status,
      'special_instructions': specialInstructions,
    };
  }
}