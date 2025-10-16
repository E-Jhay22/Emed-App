// Appointment model

class Appointment {
  final String id;
  final String userId;
  final String? staffId;
  final DateTime requestedAt;
  final DateTime? scheduledAt;
  final String status; // requested | scheduled | completed | cancelled
  final String? notes;
  // Display names hydrated from profiles
  final String? requestedByName;
  final String? scheduledByName;

  Appointment({
    required this.id,
    required this.userId,
    this.staffId,
    required this.requestedAt,
    this.scheduledAt,
    required this.status,
    this.notes,
    this.requestedByName,
    this.scheduledByName,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    staffId: json['staff_id'] as String?,
    requestedAt: DateTime.parse(json['requested_at'] as String),
    scheduledAt: json['scheduled_at'] != null
        ? DateTime.parse(json['scheduled_at'] as String)
        : null,
    status: json['status'] as String? ?? 'requested',
    notes: json['notes'] as String?,
    // If API returns nested aliases, capture them optionally
    requestedByName:
        (json['requested_by_name'] as String?) ??
        ((json['user'] is Map && (json['user'] as Map)['full_name'] != null)
            ? (json['user'] as Map)['full_name'] as String
            : null),
    scheduledByName:
        (json['scheduled_by_name'] as String?) ??
        ((json['staff'] is Map && (json['staff'] as Map)['full_name'] != null)
            ? (json['staff'] as Map)['full_name'] as String
            : null),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'staff_id': staffId,
    'requested_at': requestedAt.toIso8601String(),
    'scheduled_at': scheduledAt?.toIso8601String(),
    'status': status,
    'notes': notes,
    // Names are view-only; not serialized for writes
  };
}
