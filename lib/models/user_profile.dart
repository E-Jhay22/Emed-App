// Profile row in the `profiles` table.

class VerificationDocuments {
  final String? selfieUrl;
  final String? idDocumentUrl;
  final String? proofOfResidenceUrl;
  final DateTime? submittedAt;
  final String? rejectionReason;

  VerificationDocuments({
    this.selfieUrl,
    this.idDocumentUrl,
    this.proofOfResidenceUrl,
    this.submittedAt,
    this.rejectionReason,
  });

  factory VerificationDocuments.fromJson(Map<String, dynamic> json) {
    return VerificationDocuments(
      selfieUrl: json['selfie_url'] as String?,
      idDocumentUrl: json['id_document_url'] as String?,
      proofOfResidenceUrl: json['proof_of_residence_url'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'selfie_url': selfieUrl,
    'id_document_url': idDocumentUrl,
    'proof_of_residence_url': proofOfResidenceUrl,
    'submitted_at': submittedAt?.toIso8601String(),
    'rejection_reason': rejectionReason,
  };
}

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String role; // 'admin' | 'staff' | 'user'
  final String? photoUrl;
  final String? username;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? address;
  final DateTime? birthday;
  final String? phone;
  final bool? disabled;
  final bool verified;
  final String?
  verificationStatus; // 'pending' | 'approved' | 'rejected' | null
  final VerificationDocuments? verificationDocuments;
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationReviewedAt;
  final String? verificationReviewedBy;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.photoUrl,
    this.username,
    this.firstName,
    this.middleName,
    this.lastName,
    this.address,
    this.birthday,
    this.phone,
    this.disabled,
    this.verified = false,
    this.verificationStatus,
    this.verificationDocuments,
    this.verificationSubmittedAt,
    this.verificationReviewedAt,
    this.verificationReviewedBy,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    fullName:
        json['full_name'] as String? ??
        ([
          json['first_name'],
          json['last_name'],
        ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(' ')),
    email: json['email'] as String? ?? '',
    role: ((json['role'] as String?) ?? 'user').trim().toLowerCase(),
    photoUrl: json['photo_url'] as String?,
    username: json['username'] as String?,
    firstName: json['first_name'] as String?,
    middleName: json['middle_name'] as String?,
    lastName: json['last_name'] as String?,
    address: json['address'] as String?,
    birthday: json['birthday'] != null
        ? DateTime.tryParse(json['birthday'].toString())
        : null,
    phone: json['phone'] as String?,
    disabled: json.containsKey('disabled')
        ? (json['disabled'] == null ? null : (json['disabled'] as bool))
        : null,
    verified: json['verified'] as bool? ?? false,
    verificationStatus: json['verification_status'] as String?,
    verificationDocuments: json['verification_documents'] != null
        ? VerificationDocuments.fromJson(
            json['verification_documents'] as Map<String, dynamic>,
          )
        : null,
    verificationSubmittedAt: json['verification_submitted_at'] != null
        ? DateTime.tryParse(json['verification_submitted_at'].toString())
        : null,
    verificationReviewedAt: json['verification_reviewed_at'] != null
        ? DateTime.tryParse(json['verification_reviewed_at'].toString())
        : null,
    verificationReviewedBy: json['verification_reviewed_by'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'role': role,
    'photo_url': photoUrl,
    'username': username,
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'address': address,
    'birthday': birthday?.toIso8601String(),
    'phone': phone,
    if (disabled != null) 'disabled': disabled,
    'verified': verified,
    'verification_status': verificationStatus,
    'verification_documents': verificationDocuments?.toJson(),
    'verification_submitted_at': verificationSubmittedAt?.toIso8601String(),
    'verification_reviewed_at': verificationReviewedAt?.toIso8601String(),
    'verification_reviewed_by': verificationReviewedBy,
  };
}
