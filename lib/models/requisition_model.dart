class SlotModel {
  final String date;
  final String from;
  final String to;

  SlotModel({required this.date, required this.from, required this.to});

  Map<String, dynamic> toMap() => {'date': date, 'from': from, 'to': to};

  factory SlotModel.fromMap(Map<String, dynamic> m) =>
      SlotModel(date: m['date'] ?? '', from: m['from'] ?? '', to: m['to'] ?? '');
}

class FacilityModel {
  bool lamp;           int lampCount;
  bool water;          int waterCount;
  bool bouquet;        int bouquetCount;
  bool photography;
  bool videography;    String videoFrom; String videoTo;
  bool projector;
  bool laptopIT;
  bool podiumMike;
  bool cordlessMike;
  bool collarMike;

  FacilityModel({
    this.lamp = false,        this.lampCount = 0,
    this.water = false,       this.waterCount = 0,
    this.bouquet = false,     this.bouquetCount = 0,
    this.photography = false,
    this.videography = false, this.videoFrom = '', this.videoTo = '',
    this.projector = false,
    this.laptopIT = false,
    this.podiumMike = false,
    this.cordlessMike = false,
    this.collarMike = false,
  });

  Map<String, dynamic> toMap() => {
    'lamp': {'selected': lamp, 'count': lampCount},
    'water': {'selected': water, 'count': waterCount},
    'bouquet': {'selected': bouquet, 'count': bouquetCount},
    'photography': {'selected': photography},
    'videography': {'selected': videography, 'from': videoFrom, 'to': videoTo},
    'projector': {'selected': projector},
    'laptopIT': {'selected': laptopIT},
    'podiumMike': {'selected': podiumMike},
    'cordlessMike': {'selected': cordlessMike},
    'collarMike': {'selected': collarMike},
  };
}

class SignatureModel {
  String initiatedName;  String initiatedSign;  String initiatedPhone;
  String forwardedName;  String forwardedSign;
  String recommendedName; String recommendedSign;
  String approvedName;   String approvedSign;

  SignatureModel({
    this.initiatedName = '',  this.initiatedSign = '',  this.initiatedPhone = '',
    this.forwardedName = '',  this.forwardedSign = '',
    this.recommendedName = '', this.recommendedSign = '',
    this.approvedName = '',   this.approvedSign = '',
  });

  Map<String, dynamic> toMap() => {
    'initiated':   {'name': initiatedName, 'sign': initiatedSign, 'phone': initiatedPhone},
    'forwarded':   {'name': forwardedName, 'sign': forwardedSign},
    'recommended': {'name': recommendedName, 'sign': recommendedSign},
    'approved':    {'name': approvedName, 'sign': approvedSign},
  };
}

class RequisitionModel {
  final String id;
  final String userId;
  final String venue;
  final String bookingDate;
  final String bookingTime;
  final List<SlotModel> slots;
  final String instituteName;
  final String eventTimeFrom;
  final String eventTimeTo;
  final String purpose;
  final String expectedStrength;
  final FacilityModel facilities;
  final String extraFurniture;
  final SignatureModel signatures;
  final String status;

  RequisitionModel({
    this.id = '',
    required this.userId,
    required this.venue,
    required this.bookingDate,
    required this.bookingTime,
    required this.slots,
    this.instituteName = 'Manav Rachna University',
    this.eventTimeFrom = '',
    this.eventTimeTo = '',
    this.purpose = '',
    this.expectedStrength = '',
    required this.facilities,
    this.extraFurniture = '',
    required this.signatures,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'venue': venue,
    'booking_date': bookingDate,
    'booking_time': bookingTime,
    'slots': slots.map((s) => s.toMap()).toList(),
    'institute_name': instituteName,
    'event_time_from': eventTimeFrom,
    'event_time_to': eventTimeTo,
    'purpose': purpose,
    'expected_strength': expectedStrength,
    'facilities': facilities.toMap(),
    'extra_furniture': extraFurniture,
    'signatures': signatures.toMap(),
    'status': status,
  };
}
