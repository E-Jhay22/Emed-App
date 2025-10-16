import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  String? _passwordStrengthError(String password) {
    final missing = <String>[];
    if (password.length < 8) missing.add('at least 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      missing.add('an uppercase letter');
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      missing.add('a lowercase letter');
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      missing.add('a number');
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      missing.add('a symbol');
    }
    if (missing.isEmpty) return null;
    return 'Password must include ${missing.join(', ')}.';
  }

  Widget _buildPasswordStrengthMeter() {
    final password = _newCtrl.text;
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
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set new password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCtrl,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) => _passwordStrengthError((v ?? '').trim()),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _buildPasswordStrengthMeter(),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Confirm your new password';
                      }
                      if (v != _newCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : FilledButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;
                            setState(() => _saving = true);
                            try {
                              await AuthService.instance.updatePassword(
                                _newCtrl.text,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password updated. You can now continue.',
                                  ),
                                ),
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to update password: ${e.toString().replaceAll('Exception: ', '')}',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                          child: const Text('Save new password'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
