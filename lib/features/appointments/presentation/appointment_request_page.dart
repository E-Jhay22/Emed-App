import 'package:flutter/material.dart';
import '../../../../models/appointment.dart';
import '../../../../services/appointment_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/auth_service.dart';
import '../../profile/presentation/verification_page.dart';

class AppointmentRequestPage extends StatefulWidget {
  const AppointmentRequestPage({super.key});

  @override
  State<AppointmentRequestPage> createState() => _AppointmentRequestPageState();
}

class _AppointmentRequestPageState extends State<AppointmentRequestPage> {
  final _notesCtl = TextEditingController();
  bool _loading = false;
  bool _checkingVerification = true;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final profile = await AuthService.instance.getProfile();
      setState(() {
        _isVerified = profile?.verified == true;
        _checkingVerification = false;
      });
    } catch (e) {
      setState(() {
        _isVerified = false;
        _checkingVerification = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) throw 'Not signed in';
      final a = Appointment(
        id: 'local-temp',
        userId: user.id,
        requestedAt: DateTime.now().toUtc(),
        scheduledAt: null,
        staffId: null,
        status: 'requested',
        notes: _notesCtl.text.trim(),
      );
      await AppointmentService.instance.requestAppointment(a);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop(a);
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);

      // show verification error
      if (e.toString().contains('identity verification')) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Please complete identity verification first'),
            action: SnackBarAction(
              label: 'Verify Now',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VerificationPage(),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Request failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildVerificationAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identity Verification Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Please complete identity verification to request appointments.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const VerificationPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Appointment')),
      body: _checkingVerification
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (!_isVerified) _buildVerificationAlert(),
                  TextFormField(
                    controller: _notesCtl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 4,
                    enabled: _isVerified,
                  ),
                  const SizedBox(height: 16),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _isVerified ? _submit : null,
                          child: const Text('Request'),
                        ),
                ],
              ),
            ),
    );
  }
}
