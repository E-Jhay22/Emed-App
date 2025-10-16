import 'package:flutter/material.dart';
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/auth/presentation/reset_password_page.dart';
import 'core/widgets/role_scope.dart';
import 'core/widgets/theme_scope.dart';
import 'services/supabase_service.dart';
import 'services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// App entry
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load .env if present
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv: .env not loaded ($e)');
    try {
      await dotenv.load(fileName: 'dotenv.env');
      debugPrint('dotenv: loaded legacy dotenv.env');
    } catch (e2) {
      debugPrint('dotenv: dotenv.env not loaded ($e2)');
    }
  }

  final defineUrl = const String.fromEnvironment('SUPABASE_URL');
  final defineKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  final supabaseUrl = defineUrl.isNotEmpty
      ? defineUrl
      : (dotenv.env['SUPABASE_URL'] ?? '');
  final supabaseAnonKey = defineKey.isNotEmpty
      ? defineKey
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_ANON_KEY via .env or --dart-define.',
    );
  }

  await SupabaseService.instance.init(
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
  );

  runApp(const EmedApp());
}

class EmedApp extends StatefulWidget {
  const EmedApp({super.key});

  @override
  State<EmedApp> createState() => _EmedAppState();
}

class _EmedAppState extends State<EmedApp> {
  final _themeController = ThemeController();
  // global messenger
  static final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: Builder(
        builder: (context) {
          final controller = ThemeScope.of(context);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Emed',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: controller.mode,
            scaffoldMessengerKey: _scaffoldMessengerKey,
            home: const RootSwitcher(),
          );
        },
      ),
    );
  }
}

class RootSwitcher extends StatefulWidget {
  const RootSwitcher({super.key});

  @override
  State<RootSwitcher> createState() => _RootSwitcherState();
}

class _RootSwitcherState extends State<RootSwitcher> {
  String? _role;
  bool _loading = true;
  StreamSubscription? _authSub;
  bool _showedDisabledDialog = false;

  @override
  void initState() {
    super.initState();
    _initAuth();
    // watch auth changes
    _authSub = SupabaseService.instance.authStateChanges.listen((state) async {
      // password recovery
      if (state.event == AuthChangeEvent.passwordRecovery) {
        if (!mounted) return;
        // open reset page
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ResetPasswordPage()));
        return;
      }

      final user = SupabaseService.instance.currentUser;
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _role = null;
        });
      } else {
        try {
          final profile = await AuthService.instance.getProfile(
            userId: user.id,
          );
          if (!mounted) return;
          // block disabled
          if (profile?.disabled == true) {
            await _handleDisabledAccount();
            return;
          }
          setState(() {
            _role = profile?.role ?? 'user';
          });
        } catch (_) {}
      }
    });
  }

  Future<void> _initAuth() async {
    // init auth
    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        final profile = await AuthService.instance.getProfile(userId: user.id);
        // disabled -> sign out
        if (profile?.disabled == true) {
          await _handleDisabledAccount();
          return;
        }
        _role = profile?.role ?? 'user';
      }
    } catch (e) {
      debugPrint('Auth init error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    bool supabaseInitialized = true;
    try {
      // touch client
      SupabaseService.instance.client;
    } catch (e) {
      supabaseInitialized = false;
    }
    if (!supabaseInitialized || SupabaseService.instance.currentUser == null) {
      return const LoginPage();
    }
    // go to dashboard
    return RoleScope(
      role: _role ?? 'user',
      child: DashboardPage(role: _role ?? 'user'),
    );
  }

  Future<void> _handleDisabledAccount() async {
    if (_showedDisabledDialog) {
      // avoid double dialogs
      await AuthService.instance.signOut();
      if (mounted) {
        setState(() {
          _role = null;
        });
      }
      return;
    }
    _showedDisabledDialog = true;
    try {
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Account Disabled'),
            content: const Text(
              'Your account has been disabled by an administrator. Contact support if you believe this is a mistake.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // snackbar fallback
      try {
        _EmedAppState._scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Account disabled. Signing out...')),
        );
      } catch (_) {}
    } finally {
      // ensure sign out
      await AuthService.instance.signOut();
      if (mounted) {
        setState(() {
          _role = null;
        });
      }
      _showedDisabledDialog = false;
    }
  }
}
