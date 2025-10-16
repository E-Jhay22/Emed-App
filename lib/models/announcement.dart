// Announcement model

class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String createdBy;
  final String? createdByName;
  final DateTime? createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.startsAt,
    this.endsAt,
    required this.createdBy,
    this.createdByName,
    this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    startsAt: json['starts_at'] != null
        ? DateTime.parse(json['starts_at'] as String)
        : null,
    endsAt: json['ends_at'] != null
        ? DateTime.parse(json['ends_at'] as String)
        : null,
    createdBy: json['created_by'] as String? ?? '',
    createdByName:
        (json['profiles'] is Map &&
            (json['profiles'] as Map)['full_name'] != null)
        ? (json['profiles'] as Map)['full_name'] as String
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse('${json['created_at']}')
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'starts_at': startsAt?.toIso8601String(),
    'ends_at': endsAt?.toIso8601String(),
    'created_by': createdBy,
    'created_at': createdAt?.toIso8601String(),
  };
}
