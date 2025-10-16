import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/verification_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_profile.dart';
import 'dart:typed_data';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  bool _loading = false;
  String? _error;
  UserProfile? _currentUser;

  XFile? _selfieFile;
  XFile? _idFile;
  XFile? _proofFile;

  Uint8List? _selfieBytes;
  Uint8List? _idBytes;
  Uint8List? _proofBytes;

  // remote previews
  String? _selfieRemoteUrl;
  String? _idRemoteUrl;
  String? _proofRemoteUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await AuthService.instance.getProfile();
      final verificationData = await VerificationService.instance
          .getCurrentUserVerification();

      final merged = profile?.copyWith(
        verified: verificationData?.verified ?? false,
        verificationStatus: verificationData?.verificationStatus,
        verificationDocuments: verificationData?.verificationDocuments,
        verificationSubmittedAt: verificationData?.verificationSubmittedAt,
        verificationReviewedAt: verificationData?.verificationReviewedAt,
      );
      setState(() {
        _currentUser = merged;
      });

      // load remote previews
      if (mounted && merged?.verificationDocuments != null) {
        // fire and forget
        _loadRemotePreviews(merged!);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadRemotePreviews(UserProfile profile) async {
    final docs = profile.verificationDocuments!;
    try {
      final futures = <Future<void>>[];
      if (docs.selfieUrl != null && _selfieBytes == null) {
        futures.add(
          VerificationService.instance
              .getDocumentSignedUrl(docs.selfieUrl!)
              .then((url) => _selfieRemoteUrl = url)
              .catchError((_) => ''),
        );
      }
      if (docs.idDocumentUrl != null && _idBytes == null) {
        futures.add(
          VerificationService.instance
              .getDocumentSignedUrl(docs.idDocumentUrl!)
              .then((url) => _idRemoteUrl = url)
              .catchError((_) => ''),
        );
      }
      if (docs.proofOfResidenceUrl != null && _proofBytes == null) {
        futures.add(
          VerificationService.instance
              .getDocumentSignedUrl(docs.proofOfResidenceUrl!)
              .then((url) => _proofRemoteUrl = url)
              .catchError((_) => ''),
        );
      }
      await Future.wait(futures);
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          switch (type) {
            case 'selfie':
              _selfieFile = image;
              _selfieBytes = bytes;
              break;
            case 'id':
              _idFile = image;
              _idBytes = bytes;
              break;
            case 'proof':
              _proofFile = image;
              _proofBytes = bytes;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickImageFromGallery(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          switch (type) {
            case 'selfie':
              _selfieFile = image;
              _selfieBytes = bytes;
              break;
            case 'id':
              _idFile = image;
              _idBytes = bytes;
              break;
            case 'proof':
              _proofFile = image;
              _proofBytes = bytes;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _showReplacePicker(String type) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickImage(type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickImageFromGallery(type);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearDocument(String type) {
    setState(() {
      switch (type) {
        case 'selfie':
          _selfieFile = null;
          _selfieBytes = null;
          _selfieRemoteUrl = null;
          break;
        case 'id':
          _idFile = null;
          _idBytes = null;
          _idRemoteUrl = null;
          break;
        case 'proof':
          _proofFile = null;
          _proofBytes = null;
          _proofRemoteUrl = null;
          break;
      }
    });
  }

  Future<void> _submitVerification() async {
    if (_selfieFile == null || _idFile == null || _proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await VerificationService.instance.submitVerificationDocuments(
        selfie: _selfieFile!,
        idDocument: _idFile!,
        proofOfResidence: _proofFile!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification documents submitted successfully! Please wait for admin review.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildDocumentCard({
    required String title,
    required String description,
    required String type,
    required XFile? file,
    required Uint8List? imageBytes,
    String? remoteUrl,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 16),
            if (imageBytes != null || remoteUrl != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.cover)
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              remoteUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (c, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (c, e, s) => const Center(
                                child: Text('Unable to load image'),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: FilledButton.tonalIcon(
                                onPressed: () =>
                                    _showDocumentViewerUrl(title, remoteUrl),
                                icon: const Icon(Icons.zoom_in),
                                label: const Text('View'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // replace / remove
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => _showReplacePicker(type),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Replace'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _loading ? null : () => _clearDocument(type),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickImage(type),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _pickImageFromGallery(type),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDocumentViewerUrl(String title, String url) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 600,
          height: 500,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stack) =>
                    Center(child: Text('Cannot display image: $error')),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Current status
                  if (_currentUser != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification Status',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              VerificationService.instance
                                  .getVerificationStatusMessage(_currentUser),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: _currentUser!.verified
                                        ? Colors.green
                                        : _currentUser!.verificationStatus ==
                                              'rejected'
                                        ? Colors.red
                                        : _currentUser!.verificationStatus ==
                                              'pending'
                                        ? Colors.orange
                                        : null,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Required Documents',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'To verify your identity, please upload clear photos of the following documents:',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• A recent selfie showing your face clearly',
                          ),
                          const Text(
                            '• Government-issued ID (driver\'s license, passport, etc.)',
                          ),
                          const Text(
                            '• Proof of residence (utility bill, bank statement, etc.)',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Make sure all documents are clear, well-lit, and all information is readable.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Document upload cards
                  _buildDocumentCard(
                    title: '📷 Selfie',
                    description:
                        'Take a clear photo of yourself holding your ID next to your face',
                    type: 'selfie',
                    file: _selfieFile,
                    imageBytes: _selfieBytes,
                    remoteUrl: _selfieRemoteUrl,
                  ),
                  const SizedBox(height: 16),

                  _buildDocumentCard(
                    title: '🆔 Government ID',
                    description:
                        'Photo of your driver\'s license, passport, or other government-issued ID',
                    type: 'id',
                    file: _idFile,
                    imageBytes: _idBytes,
                    remoteUrl: _idRemoteUrl,
                  ),
                  const SizedBox(height: 16),

                  _buildDocumentCard(
                    title: '🏠 Proof of Residence',
                    description:
                        'Recent utility bill, bank statement, or lease agreement showing your address',
                    type: 'proof',
                    file: _proofFile,
                    imageBytes: _proofBytes,
                    remoteUrl: _proofRemoteUrl,
                  ),
                  const SizedBox(height: 24),

                  // submit
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          (_selfieFile != null &&
                              _idFile != null &&
                              _proofFile != null &&
                              !_loading)
                          ? _submitVerification
                          : null,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(
                        _loading ? 'Submitting...' : 'Submit for Verification',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

// Extension to add copyWith method to UserProfile if it doesn't exist
extension UserProfileCopyWith on UserProfile {
  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? photoUrl,
    String? username,
    String? firstName,
    String? middleName,
    String? lastName,
    String? address,
    DateTime? birthday,
    String? phone,
    bool? disabled,
    bool? verified,
    String? verificationStatus,
    VerificationDocuments? verificationDocuments,
    DateTime? verificationSubmittedAt,
    DateTime? verificationReviewedAt,
    String? verificationReviewedBy,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      address: address ?? this.address,
      birthday: birthday ?? this.birthday,
      phone: phone ?? this.phone,
      disabled: disabled ?? this.disabled,
      verified: verified ?? this.verified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationDocuments:
          verificationDocuments ?? this.verificationDocuments,
      verificationSubmittedAt:
          verificationSubmittedAt ?? this.verificationSubmittedAt,
      verificationReviewedAt:
          verificationReviewedAt ?? this.verificationReviewedAt,
      verificationReviewedBy:
          verificationReviewedBy ?? this.verificationReviewedBy,
    );
  }
}
