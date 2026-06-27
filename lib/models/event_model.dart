class EventModel {
  final String id;
  final String organizerId;
  final String eventName;
  final String organization;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String roomId;
  final int expectedCrowd;
  final List<String> resources;
  final String status; // pending, approved, rejected, completed
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

  Map<String, dynamic> toMap() {
    return {
      'organizerId': organizerId,
      'eventName': eventName,
      'organization': organization,
      'date': date.toIso8601String(),
      'startTime': startTime.hour * 60 + startTime.minute,
      'endTime': endTime.hour * 60 + endTime.minute,
      'roomId': roomId,
      'expectedCrowd': expectedCrowd,
      'resources': resources,
      'status': status,
      'specialInstructions': specialInstructions,
    };
  }
}
