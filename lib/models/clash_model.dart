class ClashModel {
  final String clashingEventId;
  final String clashingEventName;
  final String venue;
  final String date;
  final String fromTime;
  final String toTime;
  final String organizerName;

  ClashModel({
    required this.clashingEventId,
    required this.clashingEventName,
    required this.venue,
    required this.date,
    required this.fromTime,
    required this.toTime,
    required this.organizerName,
  });

  Map<String, dynamic> toMap() {
    return {
      'clashingEventId': clashingEventId,
      'clashingEventName': clashingEventName,
      'venue': venue,
      'date': date,
      'fromTime': fromTime,
      'toTime': toTime,
      'organizerName': organizerName,
    };
  }

  factory ClashModel.fromMap(Map<String, dynamic> map) {
    return ClashModel(
      clashingEventId: map['clashingEventId'] ?? '',
      clashingEventName: map['clashingEventName'] ?? 'Another Event',
      venue: map['venue'] ?? '',
      date: map['date'] ?? '',
      fromTime: map['fromTime'] ?? '',
      toTime: map['toTime'] ?? '',
      organizerName: map['organizerName'] ?? 'Unknown',
    );
  }
}