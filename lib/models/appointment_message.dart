class AppointmentMessage {
  final String id;
  final String appointmentId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  AppointmentMessage({
    required this.id,
    required this.appointmentId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });

  factory AppointmentMessage.fromJson(Map<String, dynamic> json) {
    return AppointmentMessage(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String? ?? 'Unknown User',
      senderRole: json['sender_role'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'appointment_id': appointmentId,
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_role': senderRole,
    'message': message,
    'created_at': createdAt.toIso8601String(),
  };

  bool get isFromStaff => senderRole == 'staff' || senderRole == 'admin';
}
