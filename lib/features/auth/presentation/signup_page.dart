import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_service.dart';
import '../../../services/phone_utils.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _birthday;
  bool _loading = false;
  bool _obscureSignupPassword = true;

  String? _passwordStrengthError(String password) {
    final missing = <String>[];
    if (password.length < 8) missing.add('at least 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      missing.add('an uppercase letter');
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) missing.add('a lowercase letter');
    if (!RegExp(r'\d').hasMatch(password)) missing.add('a number');
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) missing.add('a symbol');
    if (missing.isEmpty) return null;
    return 'Password must include ${missing.join(', ')}.';
  }

  Widget _buildPasswordStrengthMeter() {
    final password = _passwordController.text;
    final checks = [
      {'label': '8+ characters', 'valid': password.length >= 8},
      {
        'label': 'Uppercase letter',
        'valid': RegExp(r'[A-Z]').hasMatch(password),
      },
      {
        'label': 'Lowercase letter',
        'valid': RegExp(r'[a-z]').hasMatch(password),
      },
      {'label': 'Number', 'valid': RegExp(r'\d').hasMatch(password)},
      {'label': 'Symbol', 'valid': RegExp(r'[^A-Za-z0-9]').hasMatch(password)},
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
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: checks.map((check) {
              final isValid = check['valid'] as bool;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isValid ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14,
                    color: isValid ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    check['label'] as String,
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _middleNameController,
                  decoration: const InputDecoration(
                    labelText: 'Middle Name (optional)',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Username is required';
                    if (t.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRe.hasMatch(t)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSignupPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _obscureSignupPassword = !_obscureSignupPassword,
                      ),
                    ),
                  ),
                  obscureText: _obscureSignupPassword,
                  validator: (v) => _passwordStrengthError(v ?? ''),
                  onChanged: (_) =>
                      setState(() {}), // trigger rebuild for strength meter
                ),
                const SizedBox(height: 8),
                _buildPasswordStrengthMeter(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
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
                          initialDate: DateTime(
                            now.year - 18,
                            now.month,
                            now.day,
                          ),
                          firstDate: DateTime(1900, 1, 1),
                          lastDate: now,
                        );
                        if (picked != null) setState(() => _birthday = picked);
                      },
                      child: const Text('Pick Birthday'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (+63 or 09...)',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null; // optional
                    return normalizePhPhone(t) == null
                        ? 'Enter a valid Philippine phone number'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          // Validate without showing loading first
                          if (!_formKey.currentState!.validate()) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fix the highlighted fields.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => _loading = true);
                          try {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text;
                            final username = _usernameController.text.trim();

                            // pre-check if email already exists
                            if (await AuthService.instance.emailInUse(email)) {
                              throw Exception('This email is already in use.');
                            }

                            await AuthService.instance.signUpWithEmail(
                              email: email,
                              password: password,
                              username: username,
                              firstName: _firstNameController.text.trim(),
                              middleName:
                                  _middleNameController.text.trim().isEmpty
                                  ? null
                                  : _middleNameController.text.trim(),
                              lastName: _lastNameController.text.trim(),
                              address: _addressController.text.trim(),
                              birthday: _birthday,
                              phone: _phoneController.text.trim(),
                            );
                            if (!mounted) return;
                            navigator.pop();
                          } catch (e) {
                            final msg = e.toString();
                            String friendly;
                            if (msg.contains('User already registered') ||
                                msg.contains('already registered') ||
                                msg.toLowerCase().contains(
                                  'email is already in use',
                                )) {
                              friendly = 'This email is already in use.';
                            } else if (msg.toLowerCase().contains('username')) {
                              friendly = 'That username is already taken.';
                            } else if (msg.toLowerCase().contains(
                              'password must include',
                            )) {
                              friendly = msg.replaceAll('Exception: ', '');
                            } else if (msg.toLowerCase().contains('phone')) {
                              friendly =
                                  'Please enter a valid Philippine phone number.';
                            } else {
                              friendly =
                                  'Sign up failed. ${msg.replaceAll('Exception: ', '')}';
                            }
                            messenger.showSnackBar(
                              SnackBar(content: Text(friendly)),
                            );
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                        child: const Text('Create account'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
