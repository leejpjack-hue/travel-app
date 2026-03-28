class Trip {
  final String id;
  final String name;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? timezone;
  final String? baseLocation;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userId;

  Trip({
    required this.id,
    required this.name,
    required this.destination,
    this.startDate,
    this.endDate,
    this.timezone,
    this.baseLocation,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
  });

  // Factory constructor to create Trip from JSON
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      name: json['name'],
      destination: json['destination'] ?? '',
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      timezone: json['timezone'],
      baseLocation: json['base_location'],
      status: json['status'] ?? 'draft',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      userId: json['user_id'],
    );
  }

  // Method to convert Trip to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'destination': destination,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'timezone': timezone,
      'base_location': baseLocation,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_id': userId,
    };
  }
}