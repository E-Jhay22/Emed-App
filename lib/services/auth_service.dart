// Auth service

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'phone_utils.dart';
import '../models/user_profile.dart';

/// Disabled account
class DisabledAccountException implements Exception {
  final String message;
  DisabledAccountException([
    this.message = 'Your account has been disabled by an administrator.',
  ]);
  @override
  String toString() => message;
}

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Sign up
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? middleName,
    String? lastName,
    String? address,
    DateTime? birthday,
    String? phone,
  }) async {
    try {
      // simple pre-checks
      if (username != null && username.trim().isNotEmpty) {
        final exists = await _supabase.client
            .from('profiles')
            .select('id')
            .ilike('username', username.trim())
            .maybeSingle();
        if (exists is Map && exists['id'] != null) {
          throw Exception('Username already taken');
        }
      }
      // normalize PH phone
      if (phone != null && phone.trim().isNotEmpty) {
        final normalized = normalizePhPhone(phone.trim());
        if (normalized == null) {
          throw Exception('Invalid Philippine phone number');
        }
        phone = normalized;
      }

      // save metadata
      final metadata = <String, dynamic>{
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
        if (firstName != null && firstName.trim().isNotEmpty)
          'first_name': firstName.trim(),
        if (middleName != null && middleName.trim().isNotEmpty)
          'middle_name': middleName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'last_name': lastName.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (birthday != null) 'birthday': birthday.toIso8601String(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone,
        // default role for new users; can be changed by admins later
        'role': 'user',
      };

      final res = await _supabase.client.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      // upsert profile if logged in
      if (res.user != null && _supabase.currentUser != null) {
        try {
          await _supabase.client.from('profiles').upsert({
            'id': res.user!.id,
            'email': email,
            'role': 'user',
            'username': username?.trim(),
            'first_name': firstName?.trim(),
            'middle_name': middleName?.trim(),
            'last_name': lastName?.trim(),
            'address': address?.trim(),
            'birthday': birthday?.toIso8601String(),
            'phone': phone,
          });
        } catch (e) {
          // ignore RLS
          debugPrint('Profile upsert skipped: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in
  Future<void> signInWithEmail({
    required String email, // may be email or username
    required String password,
  }) async {
    try {
      // username -> email via RPC
      final looksLikeEmail = email.contains('@');
      String loginEmail = email;
      if (!looksLikeEmail) {
        final rpcEmail = await _supabase.client.rpc(
          'email_for_username',
          params: {'u': email},
        );
        if (rpcEmail is String && rpcEmail.isNotEmpty) {
          loginEmail = rpcEmail;
        } else {
          throw Exception('Invalid login credentials');
        }
      }
      await _supabase.client.auth.signInWithPassword(
        email: loginEmail,
        password: password,
      );
      // sync metadata
      await _ensureProfileFromAuthMetadata();
      // block disabled
      try {
        final prof = await getProfile();
        if (prof?.disabled == true) {
          await _supabase.client.auth.signOut();
          throw DisabledAccountException();
        }
      } catch (_) {}
    } catch (e) {
      rethrow;
    }
  }

  /// Send reset email
  Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    try {
      // default redirect
      final fallbackRedirect = kIsWeb
          ? Uri
                .base
                .origin // e.g., https://your-app.domain
          : 'io.supabase.flutter://reset-callback';
      await _supabase.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo ?? fallbackRedirect,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('User does not have an email');
    }
    // re-auth first
    await _supabase.client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    // update
    await _supabase.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Update password (session)
  Future<void> updatePassword(String newPassword) async {
    if (_supabase.currentUser == null) {
      throw Exception('Not authenticated');
    }
    await _supabase.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    await _supabase.client.auth.signOut();
  }

  User? get currentUser => _supabase.currentUser;

  /// Email exists?
  Future<bool> emailInUse(String email) async {
    final row = await _supabase.client
        .from('profiles')
        .select('id')
        .ilike('email', email.trim())
        .maybeSingle();
    return row is Map && row['id'] != null;
  }

  /// Get profile
  Future<UserProfile?> getProfile({String? userId}) async {
    final id = userId ?? currentUser?.id;
    if (id == null) return null;
    final resp = await _supabase.client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();

    // normalize shapes
    try {
      // case: data key
      if (resp is Map && resp.containsKey('data')) {
        final d = resp['data'];
        if (d == null) return null;
        final map = d is List
            ? (d.isNotEmpty ? d.first as Map<String, dynamic> : null)
            : d as Map<String, dynamic>?;
        if (map == null) return null;
        return UserProfile.fromJson(map);
      }

      // case: map row
      if (resp is Map<String, dynamic>) {
        return UserProfile.fromJson(resp);
      }

      // case: other
      if (resp != null) {
        // probe
        final asMap = Map<String, dynamic>.from(resp as Map);
        if (asMap.containsKey('id')) {
          return UserProfile.fromJson(asMap);
        }
      }
    } catch (e) {
      // ignore parse errors
      debugPrint('getProfile normalization error: $e');
    }

    // backfill then retry
    try {
      await _ensureProfileFromAuthMetadata();
    } catch (_) {}
    try {
      final retry = await _supabase.client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (retry is Map<String, dynamic>) {
        return UserProfile.fromJson(retry);
      }
    } catch (_) {}
    // final fallback
    try {
      await _ensureProfileRow(id);
    } catch (_) {
      // ignore
    }
    return null;
  }

  /// Ensure minimal profile
  Future<void> _ensureProfileRow(String id) async {
    // insert if missing
    try {
      final existing = await _supabase.client
          .from('profiles')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      if (existing is Map && existing['id'] != null) return;
    } catch (_) {}
    try {
      await _supabase.client.from('profiles').insert({
        'id': id,
        'role': 'user',
      });
    } catch (_) {
      // Ignore duplicate or RLS errors.
    }
  }

  /// Ensure profile from metadata
  Future<void> _ensureProfileFromAuthMetadata() async {
    final u = _supabase.currentUser;
    if (u == null) return;

    // gather metadata
    final meta = (u.userMetadata ?? const {}) as Map;
    String? mUsername = (meta['username'] as String?)?.trim();
    String? mFirst = (meta['first_name'] as String?)?.trim();
    String? mMiddle = (meta['middle_name'] as String?)?.trim();
    String? mLast = (meta['last_name'] as String?)?.trim();
    String? mAddr = (meta['address'] as String?)?.trim();
    String? mPhone = (meta['phone'] as String?)?.trim();
    String? mRole = (meta['role'] as String?)?.trim();
    String? mBdayRaw = meta['birthday']?.toString();
    String? mBdayIso;
    if (mBdayRaw != null && mBdayRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(mBdayRaw);
      if (parsed != null) mBdayIso = parsed.toIso8601String();
    }

    // normalize phone
    if (mPhone != null && mPhone.isNotEmpty) {
      final normalized = normalizePhPhone(mPhone);
      if (normalized != null) mPhone = normalized;
    }

    try {
      final existing = await _supabase.client
          .from('profiles')
          .select('id, role')
          .eq('id', u.id)
          .maybeSingle();

      if (existing is Map && existing['id'] != null) {
        // update basic fields
        final update = <String, dynamic>{
          if (u.email != null && u.email!.isNotEmpty) 'email': u.email,
          if (mUsername != null && mUsername.isNotEmpty) 'username': mUsername,
          if (mFirst != null && mFirst.isNotEmpty) 'first_name': mFirst,
          if (mMiddle != null && mMiddle.isNotEmpty) 'middle_name': mMiddle,
          if (mLast != null && mLast.isNotEmpty) 'last_name': mLast,
          if (mAddr != null && mAddr.isNotEmpty) 'address': mAddr,
          if (mBdayIso != null && mBdayIso.isNotEmpty) 'birthday': mBdayIso,
          if (mPhone != null && mPhone.isNotEmpty) 'phone': mPhone,
        };
        if (update.isEmpty) return;
        await _supabase.client.from('profiles').update(update).eq('id', u.id);
      } else {
        // insert with role
        final insert = <String, dynamic>{
          'id': u.id,
          if (u.email != null && u.email!.isNotEmpty) 'email': u.email,
          'role': (mRole != null && mRole.isNotEmpty)
              ? mRole.toLowerCase()
              : 'user',
          if (mUsername != null && mUsername.isNotEmpty) 'username': mUsername,
          if (mFirst != null && mFirst.isNotEmpty) 'first_name': mFirst,
          if (mMiddle != null && mMiddle.isNotEmpty) 'middle_name': mMiddle,
          if (mLast != null && mLast.isNotEmpty) 'last_name': mLast,
          if (mAddr != null && mAddr.isNotEmpty) 'address': mAddr,
          if (mBdayIso != null && mBdayIso.isNotEmpty) 'birthday': mBdayIso,
          if (mPhone != null && mPhone.isNotEmpty) 'phone': mPhone,
        };
        await _supabase.client.from('profiles').insert(insert);
      }
    } catch (e) {
      debugPrint('ensureProfileFromAuthMetadata failed: $e');
    }
  }

  // full_name from DB trigger

  /// Update profile
  Future<void> updateProfileFields({
    String? username,
    String? firstName,
    String? middleName,
    String? lastName,
    String? address,
    DateTime? birthday,
    String? phone,
  }) async {
    final id = currentUser?.id;
    if (id == null) throw Exception('Not authenticated');

    final update = <String, dynamic>{};
    if (username != null) {
      final u = username.trim();
      if (u.isEmpty) throw Exception('Username cannot be empty');
      // pre-check username
      final exists = await _supabase.client
          .from('profiles')
          .select('id')
          .ilike('username', u)
          .neq('id', id)
          .maybeSingle();
      if (exists is Map && exists['id'] != null) {
        throw Exception('Username already taken');
      }
      update['username'] = u;
    }
    if (firstName != null) update['first_name'] = firstName.trim();
    if (middleName != null) update['middle_name'] = middleName.trim();
    if (lastName != null) update['last_name'] = lastName.trim();
    if (address != null) update['address'] = address.trim();
    if (birthday != null) update['birthday'] = birthday.toIso8601String();
    if (phone != null) {
      final normalized = normalizePhPhone(phone);
      if (normalized == null) {
        throw Exception('Invalid Philippine phone number');
      }
      update['phone'] = normalized;
    }

    if (update.isEmpty) return;
    final resp = await _supabase.client
        .from('profiles')
        .update(update)
        .eq('id', id)
        .select();
    if (resp is List && resp.isEmpty) {
      throw Exception('Update failed or no changes applied');
    }
  }
}
