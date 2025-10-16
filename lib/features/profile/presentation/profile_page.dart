import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/theme_scope.dart';
import '../../../core/widgets/role_scope.dart';
import '../../../services/auth_service.dart';
import '../../../services/verification_service.dart';
import '../../../models/user_profile.dart';
import 'verification_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _savingDetails = false;
  String _email = '';
  String _role = 'user';
  DateTime? _birthday;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await AuthService.instance.getProfile();
    setState(() {
      _fullNameCtrl.text = profile?.fullName ?? '';
      _usernameCtrl.text = profile?.username ?? '';
      _firstNameCtrl.text = profile?.firstName ?? '';
      _middleNameCtrl.text = profile?.middleName ?? '';
      _lastNameCtrl.text = profile?.lastName ?? '';
      _addressCtrl.text = profile?.address ?? '';
      _phoneCtrl.text = profile?.phone ?? '';
      _birthday = profile?.birthday;
      _email = profile?.email ?? '';
      _role = profile?.role ?? RoleScope.of(context);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = ThemeScope.of(context);
    final isDark = themeCtrl.mode == ThemeMode.dark;
    return AppScaffold(
      title: 'Profile',
      currentLabel: 'Profile',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                _headerCard(isDark),
                const SizedBox(height: 12),
                _infoCard(),
                const SizedBox(height: 12),
                _verificationCard(),
                const SizedBox(height: 12),
                _detailsCard(),
                const SizedBox(height: 12),
                _securityCard(),
                const SizedBox(height: 12),
                _settingsCard(isDark, themeCtrl),
              ],
            ),
    );
  }

  Widget _headerCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 400;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Hero(
                      tag: 'avatar-hero',
                      child: CircleAvatar(
                        radius: 36,
                        child: Icon(Icons.person),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.badge),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fullNameCtrl.text,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_email, style: Theme.of(context).textTheme.bodyMedium),
                ],
              );
            }
            return Row(
              children: [
                const Hero(
                  tag: 'avatar-hero',
                  child: CircleAvatar(radius: 36, child: Icon(Icons.person)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fullNameCtrl.text,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _securityCard() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    // Persist visibility toggles within the StatefulBuilder lifecycle
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    String? validatePassword(String? v) {
      final t = (v ?? '').trim();
      if (t.length < 8) return 'Minimum 8 characters';
      if (!RegExp(r'[A-Z]').hasMatch(t)) return 'Include an uppercase letter';
      if (!RegExp(r'[a-z]').hasMatch(t)) return 'Include a lowercase letter';
      if (!RegExp(r'\d').hasMatch(t)) return 'Include a number';
      if (!RegExp(r'[^A-Za-z0-9]').hasMatch(t)) return 'Include a symbol';
      return null;
    }

    Widget passwordStrengthMeter() {
      final password = newCtrl.text;
      final checks = [
        {'label': '8+ characters', 'valid': password.length >= 8},
        {'label': 'Uppercase', 'valid': RegExp(r'[A-Z]').hasMatch(password)},
        {'label': 'Lowercase', 'valid': RegExp(r'[a-z]').hasMatch(password)},
        {'label': 'Number', 'valid': RegExp(r'\d').hasMatch(password)},
        {
          'label': 'Symbol',
          'valid': RegExp(r'[^A-Za-z0-9]').hasMatch(password),
        },
      ];
      final validCount = checks.where((c) => c['valid'] as bool).length;
      final strength = validCount / checks.length;
      Color barColor;
      String strengthText;
      if (validCount == 0) {
        barColor = Colors.grey;
        strengthText = '';
      } else if (validCount <= 2) {
        barColor = Colors.red;
        strengthText = 'Weak';
      } else if (validCount <= 4) {
        barColor = Colors.orange;
        strengthText = 'Fair';
      } else {
        barColor = Colors.green;
        strengthText = 'Strong';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (password.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: strength,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  strengthText,
                  style: TextStyle(
                    color: barColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: checks.map((c) {
                final isValid = c['valid'] as bool;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isValid
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: isValid ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      c['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isValid ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            return Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Security',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: currentCtrl,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setLocalState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                      ),
                    ),
                    obscureText: obscureCurrent,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: newCtrl,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setLocalState(() => obscureNew = !obscureNew),
                      ),
                    ),
                    obscureText: obscureNew,
                    validator: validatePassword,
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  passwordStrengthMeter(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: confirmCtrl,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setLocalState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                    ),
                    obscureText: obscureConfirm,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirm your new password';
                      }
                      if (v != newCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: saving
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: Padding(
                              padding: EdgeInsets.all(6.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              setLocalState(() => saving = true);
                              try {
                                await AuthService.instance.changePassword(
                                  currentPassword: currentCtrl.text,
                                  newPassword: newCtrl.text,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated'),
                                  ),
                                );
                                currentCtrl.clear();
                                newCtrl.clear();
                                confirmCtrl.clear();
                              } catch (e) {
                                if (!context.mounted) return;
                                final msg = e.toString();
                                String friendly = 'Failed to update password.';
                                if (msg.contains('Invalid login credentials') ||
                                    msg.contains('invalid_grant')) {
                                  friendly = 'Current password is incorrect.';
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(friendly)),
                                );
                              } finally {
                                if (mounted) {
                                  setLocalState(() => saving = false);
                                }
                              }
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Change password'),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Info', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.verified_user),
              title: const Text('Role'),
              subtitle: Text(_role),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(_email),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username (unique)',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                if (w < 480) {
                  // Stack vertically on small screens
                  return Column(
                    children: [
                      TextField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'First name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _middleNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Middle name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ],
                  );
                } else if (w < 800) {
                  // Two columns: first/last on top row, middle full-width below
                  final half = (w - 12) / 2;
                  return Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: half,
                            child: TextField(
                              controller: _firstNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'First name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: half,
                            child: TextField(
                              controller: _lastNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Last name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _middleNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Middle name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Spacious: three columns
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _middleNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Middle name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 480) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _birthday == null
                            ? 'Birthday: not set'
                            : 'Birthday: ${DateFormat.yMMMMd().format(_birthday!)}',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _birthday ??
                                  DateTime(now.year - 18, now.month, now.day),
                              firstDate: DateTime(1900, 1, 1),
                              lastDate: now,
                            );
                            if (picked != null) {
                              setState(() => _birthday = picked);
                            }
                          },
                          child: const Text('Pick birthday'),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        _birthday == null
                            ? 'Birthday: not set'
                            : 'Birthday: ${DateFormat.yMMMMd().format(_birthday!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _birthday ??
                              DateTime(now.year - 18, now.month, now.day),
                          firstDate: DateTime(1900, 1, 1),
                          lastDate: now,
                        );
                        if (picked != null) setState(() => _birthday = picked);
                      },
                      child: const Text('Pick birthday'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (+63 or 09...)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _savingDetails
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.all(6.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() => _savingDetails = true);
                              try {
                                await AuthService.instance.updateProfileFields(
                                  username: _usernameCtrl.text.trim().isEmpty
                                      ? null
                                      : _usernameCtrl.text.trim(),
                                  firstName: _firstNameCtrl.text.trim().isEmpty
                                      ? null
                                      : _firstNameCtrl.text.trim(),
                                  middleName:
                                      _middleNameCtrl.text.trim().isEmpty
                                      ? null
                                      : _middleNameCtrl.text.trim(),
                                  lastName: _lastNameCtrl.text.trim().isEmpty
                                      ? null
                                      : _lastNameCtrl.text.trim(),
                                  address: _addressCtrl.text.trim().isEmpty
                                      ? null
                                      : _addressCtrl.text.trim(),
                                  birthday: _birthday,
                                  phone: _phoneCtrl.text.trim().isEmpty
                                      ? null
                                      : _phoneCtrl.text.trim(),
                                );
                                // Refresh header full name after DB trigger runs
                                final refreshed = await AuthService.instance
                                    .getProfile();
                                if (refreshed != null) {
                                  setState(() {
                                    _fullNameCtrl.text = refreshed.fullName;
                                  });
                                }
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated'),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                final msg = e.toString().toLowerCase();
                                String friendly;
                                if (msg.contains('username') &&
                                    msg.contains('taken')) {
                                  friendly = 'That username is already taken.';
                                } else if (msg.contains('phone')) {
                                  friendly =
                                      'Please enter a valid Philippine phone number.';
                                } else {
                                  friendly =
                                      'Update failed. '
                                      '${e.toString().replaceAll('Exception: ', '')}';
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(friendly)),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _savingDetails = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save details'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(bool isDark, ThemeController themeCtrl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark'),
                  ),
                ],
                selected: {themeCtrl.mode},
                onSelectionChanged: (selection) {
                  final mode = selection.first;
                  setState(() => themeCtrl.setMode(mode));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verificationCard() {
    return FutureBuilder<UserProfile?>(
      future: VerificationService.instance.getCurrentUserVerification(),
      builder: (context, snapshot) {
        final verificationData = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user),
                    const SizedBox(width: 8),
                    Text(
                      'Identity Verification',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (verificationData?.verified == true)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else if (verificationData?.verificationStatus == 'pending')
                      const Icon(Icons.schedule, color: Colors.orange)
                    else if (verificationData?.verificationStatus == 'rejected')
                      const Icon(Icons.cancel, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Text(
                    VerificationService.instance.getVerificationStatusMessage(
                      verificationData,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: verificationData?.verified == true
                          ? Colors.green
                          : verificationData?.verificationStatus == 'rejected'
                          ? Colors.red
                          : verificationData?.verificationStatus == 'pending'
                          ? Colors.orange
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (verificationData?.verified != true) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const VerificationPage(),
                                ),
                              )
                              .then(
                                (_) => setState(() {}),
                              ); // Refresh when coming back
                        },
                        icon: Icon(
                          verificationData?.verificationStatus == 'rejected'
                              ? Icons.refresh
                              : Icons.upload,
                        ),
                        label: Text(
                          verificationData?.verificationStatus == 'rejected'
                              ? 'Resubmit Documents'
                              : verificationData?.verificationStatus ==
                                    'pending'
                              ? 'View Submission'
                              : 'Submit Documents',
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your identity has been verified! You now have full access to all app features.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                if (verificationData?.verificationDocuments?.rejectionReason !=
                    null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rejection Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                verificationData!
                                    .verificationDocuments!
                                    .rejectionReason!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
