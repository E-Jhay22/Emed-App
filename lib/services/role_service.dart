import '../models/user_profile.dart';
import 'supabase_service.dart';

class RoleService {
  RoleService._privateConstructor();
  static final RoleService instance = RoleService._privateConstructor();

  final _client = SupabaseService.instance.client;

  /// List all profiles (admin-only).
  Future<List<UserProfile>> listProfiles() async {
    final List<dynamic> data = await _client.from('profiles').select();
    return data
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Update a user's role.
  Future<void> updateRole(String userId, String role) async {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'admin') {
      // For safety, disallow promoting to admin from the app
      throw Exception('Promoting to admin is not allowed from the app.');
    }
    try {
      // Use SECURITY DEFINER RPC so DB trigger allows privileged field change
      await _client.rpc(
        'admin_update_profile_role',
        params: {'p_user_id': userId, 'p_role': normalized},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Paginated list with search, filter, sort.
  Future<List<UserProfile>> listProfilesPaged({
    String? search,
    String? roleFilter,
    String sortBy = 'created_at',
    bool ascending = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    dynamic query = _client.from('profiles').select();
    if (search != null && search.trim().isNotEmpty) {
      final s = '%${search.trim()}%';
      query = query.or('email.ilike.$s,username.ilike.$s,full_name.ilike.$s');
    }
    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.eq('role', roleFilter);
    }
    query = query.order(sortBy, ascending: ascending);
    final from = (page - 1) * pageSize;
    final to = from + pageSize - 1;
    query = query.range(from, to);
    final List<dynamic> data = await query;
    return data
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Disable or enable a user.
  Future<void> setDisabled(String userId, bool disabled) async {
    // Prevent disabling admin accounts at client level
    if (disabled) {
      final List<dynamic> target = await _client
          .from('profiles')
          .select('id, role')
          .eq('id', userId);
      if (target.isNotEmpty) {
        final r = (target.first as Map<String, dynamic>)['role']
            ?.toString()
            .toLowerCase();
        if (r == 'admin') {
          throw Exception('Disabling admin accounts is not allowed.');
        }
      }
    }
    // Use SECURITY DEFINER RPC so DB trigger allows privileged field change
    await _client.rpc(
      'admin_set_profile_disabled',
      params: {'p_user_id': userId, 'p_disabled': disabled},
    );
  }

  /// Count users by role.
  Future<Map<String, int>> countByRole() async {
    final roles = ['user', 'staff', 'admin'];
    final Map<String, int> out = {};
    for (final r in roles) {
      final List<dynamic> rows = await _client
          .from('profiles')
          .select('id')
          .eq('role', r);
      out[r] = rows.length;
    }
    return out;
  }
}
