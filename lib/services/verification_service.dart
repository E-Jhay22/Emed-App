import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart' as mime;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/user_profile.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class VerificationService {
  VerificationService._privateConstructor();
  static final VerificationService instance =
      VerificationService._privateConstructor();

  final _client = SupabaseService.instance.client;
  final _storage = SupabaseService.instance.client.storage;

  // upload one document
  Future<String> uploadDocument(XFile file, String documentType) async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final fileExtension = file.path.split('.').last.toLowerCase();
    final fileName =
        '${user.id}/$documentType-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    try {
      final fileBytes = await file.readAsBytes();

      // detect mime
      String? detectedMime = mime.lookupMimeType(
        file.path,
        headerBytes: fileBytes.isNotEmpty
            ? fileBytes.sublist(
                0,
                fileBytes.length > 32 ? 32 : fileBytes.length,
              )
            : null,
      );

      detectedMime ??= _mimeFromExtension(fileExtension);

      // allow images only
      if (detectedMime == null || !detectedMime.startsWith('image/')) {
        throw Exception(
          'Unsupported file type. Please upload an image (jpg, png, heic, webp).',
        );
      }

      await _storage
          .from('verification-documents')
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: supa.FileOptions(contentType: detectedMime),
          );

      // return storage path
      return fileName;
    } catch (e) {
      throw Exception('Failed to upload $documentType: $e');
    }
  }

  String? _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  // submit all docs
  Future<void> submitVerificationDocuments({
    required XFile selfie,
    required XFile idDocument,
    required XFile proofOfResidence,
  }) async {
    try {
      // upload all
      final selfieUrl = await uploadDocument(selfie, 'selfie');
      final idUrl = await uploadDocument(idDocument, 'id');
      final proofUrl = await uploadDocument(proofOfResidence, 'proof');

      // call RPC
      await _client.rpc(
        'submit_verification_documents',
        params: {
          'p_selfie_url': selfieUrl,
          'p_id_document_url': idUrl,
          'p_proof_of_residence_url': proofUrl,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // signed url for admin
  Future<String> getDocumentSignedUrl(String path) async {
    try {
      final signedUrl = await _storage
          .from('verification-documents')
          .createSignedUrl(path, 3600);
      return signedUrl;
    } catch (e) {
      throw Exception('Failed to get document URL: $e');
    }
  }

  // current user status
  Future<UserProfile?> getCurrentUserVerification() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return null;

    try {
      final List<dynamic> response = await _client
          .from('profiles')
          .select(
            'id, verified, verification_status, verification_documents, verification_submitted_at, verification_reviewed_at',
          )
          .eq('id', user.id)
          .limit(1);

      if (response.isEmpty) return null;

      return UserProfile.fromJson(response.first as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get verification status: $e');
    }
  }

  // admin: pending list
  Future<List<UserProfile>> getPendingVerifications() async {
    try {
      final List<dynamic> response = await _client
          .from('profiles')
          .select('*')
          .eq('verification_status', 'pending')
          .order('verification_submitted_at', ascending: true);

      return response
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pending verifications: $e');
    }
  }

  // admin: approve
  Future<void> approveVerification(String userId) async {
    try {
      await _client.rpc(
        'admin_approve_verification',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      throw Exception('Failed to approve verification: $e');
    }
  }

  // admin: reject
  Future<void> rejectVerification(String userId, String reason) async {
    try {
      await _client.rpc(
        'admin_reject_verification',
        params: {'p_user_id': userId, 'p_reason': reason},
      );
    } catch (e) {
      throw Exception('Failed to reject verification: $e');
    }
  }

  // admin: stats
  Future<Map<String, int>> getVerificationStats() async {
    try {
      final List<dynamic> pending = await _client
          .from('profiles')
          .select('id')
          .eq('verification_status', 'pending');

      final List<dynamic> verified = await _client
          .from('profiles')
          .select('id')
          .eq('verified', true);

      final List<dynamic> rejected = await _client
          .from('profiles')
          .select('id')
          .eq('verification_status', 'rejected');

      return {
        'pending': pending.length,
        'verified': verified.length,
        'rejected': rejected.length,
      };
    } catch (e) {
      throw Exception('Failed to get verification stats: $e');
    }
  }

  // has partial docs?
  bool hasPartialVerification(UserProfile? profile) {
    return profile?.verificationDocuments != null &&
        (profile?.verificationStatus == null ||
            profile?.verificationStatus == 'rejected');
  }

  // status label
  String getVerificationStatusMessage(UserProfile? profile) {
    if (profile == null) return 'Not started';

    if (profile.verified) {
      return 'Verified ✓';
    }

    switch (profile.verificationStatus) {
      case 'pending':
        return 'Under review - Please wait for admin approval';
      case 'rejected':
        final reason = profile.verificationDocuments?.rejectionReason;
        return 'Rejected${reason != null ? ': $reason' : ''}';
      default:
        return 'Not verified - Please submit your documents';
    }
  }
}
