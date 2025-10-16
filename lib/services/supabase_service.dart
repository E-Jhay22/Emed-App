// SupabaseService: singleton wrapper around Supabase client
// NOTE: Add `supabase_flutter` dependency in pubspec.yaml and insert your Supabase URL and anon key.

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._privateConstructor();
  static final SupabaseService instance = SupabaseService._privateConstructor();

  SupabaseClient? _client;

  /// Public client getter after init()
  SupabaseClient get client => _client!;

  Future<void> init({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      // Ensure incoming deep links like io.supabase.flutter://reset-callback are handled
      authCallbackUrlHostname: 'reset-callback',
    );
    _client = Supabase.instance.client;
  }

  // Auth helpers
  /// Current authenticated user (nullable)
  User? get currentUser => _client?.auth.currentUser;

  /// Auth state stream
  Stream<AuthState> get authStateChanges => _client!.auth.onAuthStateChange;

  // Database helpers will be added in specific services (inventory, announcements, appointments)
}
