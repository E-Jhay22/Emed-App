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
  // Cancellation fields
  final DateTime? cancelledAt;
  final String? cancelledBy; // id
  final String? cancelRequestReason;
  final DateTime? cancelRequestAt;

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
    this.cancelledAt,
    this.cancelledBy,
    this.cancelRequestReason,
    this.cancelRequestAt,
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
    cancelledAt: json['cancelled_at'] != null
        ? DateTime.tryParse(json['cancelled_at'].toString())
        : null,
    cancelledBy: json['cancelled_by'] as String?,
    cancelRequestReason: json['cancel_request_reason'] as String?,
    cancelRequestAt: json['cancel_request_at'] != null
        ? DateTime.tryParse(json['cancel_request_at'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'staff_id': staffId,
    'requested_at': requestedAt.toIso8601String(),
    'scheduled_at': scheduledAt?.toIso8601String(),
    'status': status,
    'notes': notes,
    'cancelled_at': cancelledAt?.toIso8601String(),
    'cancelled_by': cancelledBy,
    'cancel_request_reason': cancelRequestReason,
    'cancel_request_at': cancelRequestAt?.toIso8601String(),
    // Names are view-only; not serialized for writes
  };
}
