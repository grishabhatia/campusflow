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

  Map<String, dynamic> toMap() => {
    'clashing_event_id': clashingEventId,
    'clashing_event_name': clashingEventName,
    'venue': venue,
    'date': date,
    'from_time': fromTime,
    'to_time': toTime,
    'organizer_name': organizerName,
  };

  factory ClashModel.fromMap(Map<String, dynamic> m) => ClashModel(
    clashingEventId:   m['clashing_event_id'] ?? '',
    clashingEventName: m['clashing_event_name'] ?? '',
    venue:             m['venue'] ?? '',
    date:              m['date'] ?? '',
    fromTime:          m['from_time'] ?? '',
    toTime:            m['to_time'] ?? '',
    organizerName:     m['organizer_name'] ?? '',
  );
}