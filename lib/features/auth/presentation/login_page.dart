import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../../core/widgets/role_scope.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscureLoginPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showError(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome to Emed',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // email or username
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Email or Username',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // password
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureLoginPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscureLoginPassword = !_obscureLoginPassword,
                        ),
                      ),
                    ),
                    obscureText: _obscureLoginPassword,
                  ),
                  const SizedBox(height: 16),

                  // login
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              if (email.isEmpty || password.isEmpty) {
                                await _showError(
                                  'Missing fields',
                                  'Please enter both email and password.',
                                );
                                return;
                              }

                              setState(() => _loading = true);
                              try {
                                await AuthService.instance.signInWithEmail(
                                  email: email,
                                  password: password,
                                );
                                final user =
                                    SupabaseService.instance.currentUser;
                                if (user == null) {
                                  if (!mounted) return;
                                  await _showError(
                                    'Login failed',
                                    'No user returned from sign-in. Check credentials.',
                                  );
                                  return;
                                }
                                final profile = await AuthService.instance
                                    .getProfile(userId: user.id);
                                if (profile == null) {
                                  if (!mounted) return;
                                  await _showError(
                                    'Profile missing',
                                    'User profile not found. Contact admin.',
                                  );
                                  return;
                                }
                                final role = profile.role;
                                if (!context.mounted) return;
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => RoleScope(
                                      role: role,
                                      child: DashboardPage(role: role),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                // disabled account already handled by app shell
                                if (e is DisabledAccountException) {
                                  return;
                                }
                                final msg = e.toString();
                                String friendly;
                                if (msg.contains('Invalid login credentials') ||
                                    msg.contains('invalid_grant')) {
                                  friendly = 'Incorrect email or password.';
                                } else if (msg.contains(
                                  'Email not confirmed',
                                )) {
                                  friendly =
                                      'Please verify your email before logging in.';
                                } else {
                                  friendly =
                                      'Login failed. ${msg.replaceAll('Exception: ', '')}';
                                }
                                if (!mounted) return;
                                await _showError('Login error', friendly);
                              } finally {
                                if (mounted) setState(() => _loading = false);
                              }
                            },
                            child: const Text('Login'),
                          ),
                        ),

                  const SizedBox(height: 8),

                  const SizedBox(height: 16),

                  // reset & signup
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final controller = TextEditingController(
                          text: _emailController.text.trim(),
                        );
                        if (!mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (context) {
                            bool sending = false;
                            return StatefulBuilder(
                              builder: (context, setLocalState) {
                                return AlertDialog(
                                  title: const Text('Reset password'),
                                  content: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: sending
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: sending
                                          ? null
                                          : () async {
                                              final email = controller.text
                                                  .trim();
                                              if (email.isEmpty ||
                                                  !email.contains('@')) {
                                                // basic guard
                                                return;
                                              }
                                              // prevent double send
                                              if (!context.mounted) return;
                                              setLocalState(
                                                () => sending = true,
                                              );
                                              try {
                                                await AuthService.instance
                                                    .sendPasswordResetEmail(
                                                      email,
                                                    );
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Reset email sent. Check your inbox.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Failed to send reset email: ${e.toString().replaceAll('Exception: ', '')}',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      child: sending
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Send'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // signup
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupPage()),
                    ),
                    child: const Text('Create an account'),
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
