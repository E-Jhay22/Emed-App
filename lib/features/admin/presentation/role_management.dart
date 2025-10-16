import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/role_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/verification_service.dart';
import '../../../../models/user_profile.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  String _myRole = 'user';
  bool _loading = true;
  String? _myId;
  String _search = '';
  String? _roleFilter;
  String _sortBy = 'created_at';
  bool _ascending = false;
  int _page = 1;
  final int _pageSize = 20;
  Map<String, int> _metrics = const {};
  String? _error;
  bool _hasNext = false;
  Timer? _searchDebounce;
  List<UserProfile> _profiles = <UserProfile>[];
  bool _listLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // get my role
      final profile = await AuthService.instance.getProfile();
      _myId = profile?.id ?? AuthService.instance.currentUser?.id;
      String? role = profile?.role;
      role ??=
          AuthService.instance.currentUser?.userMetadata?['role'] as String?;
      // sometimes in app metadata
      // ignore: avoid_dynamic_calls
      role ??=
          (AuthService.instance.currentUser?.appMetadata['role'] as String?);
      final normalized = (role ?? '').trim().toLowerCase();
      _myRole = normalized.isEmpty ? 'user' : normalized;

      if (_myRole != 'admin') {
        _profiles = <UserProfile>[];
        return;
      }

      _profiles = await _loadPage();
      _metrics = await RoleService.instance.countByRole();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      if (!mounted) return;
      setState(() {
        _error = null;
        _listLoading = true;
      });
      final list = await _loadPage();
      _profiles = list;
      _metrics = await RoleService.instance.countByRole();
      if (mounted) setState(() => _listLoading = false);
    } catch (e) {
      _error = e.toString();
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<List<UserProfile>> _loadPage() async {
    // one extra to detect next
    final list = await RoleService.instance.listProfilesPaged(
      search: _search,
      roleFilter: _roleFilter,
      sortBy: _sortBy,
      ascending: _ascending,
      page: _page,
      pageSize: _pageSize + 1,
    );
    _hasNext = list.length > _pageSize;
    if (_hasNext) {
      return list.sublist(0, _pageSize);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _init,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (_myRole != 'admin') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('Access denied. Admins only.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _init,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildControls(context),
                ),
                if (_listLoading) const LinearProgressIndicator(minHeight: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildMetricsRow(),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                if (_profiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No users')),
                  ),
                ..._profiles.map((p) {
                  final hasUsername =
                      (p.username != null && p.username!.trim().isNotEmpty);
                  final isSelf = (p.id == _myId);
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(child: Text(_initialFor(p))),
                        isThreeLine: true,
                        title: Text(
                          p.fullName.isNotEmpty
                              ? p.fullName
                              : (hasUsername
                                    ? '@${p.username!.trim()}'
                                    : p.email),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasUsername)
                              Text(
                                '@${p.username!.trim()}',
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              p.email,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(p.role.toUpperCase()),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (p.disabled == true)
                                  Chip(
                                    label: const Text('DISABLED'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.red.withOpacity(
                                      0.1,
                                    ),
                                  ),
                                if (p.verified)
                                  Chip(
                                    label: const Text('VERIFIED'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.green.withOpacity(
                                      0.1,
                                    ),
                                  )
                                else if (p.verificationStatus == 'pending')
                                  Chip(
                                    label: const Text('PENDING'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.orange.withOpacity(
                                      0.1,
                                    ),
                                  )
                                else if (p.verificationStatus == 'rejected')
                                  Chip(
                                    label: const Text('REJECTED'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.red.withOpacity(
                                      0.1,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Actions',
                          enabled: !_loading,
                          onSelected: (value) async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (value.startsWith('role:')) {
                              if (isSelf) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "You can't change your own role here.",
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              final role = value.split(':')[1];
                              try {
                                await RoleService.instance.updateRole(
                                  p.id,
                                  role,
                                );
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Role updated to $role'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to update role: $e',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            } else if (value == 'toggle:disable') {
                              if (isSelf) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "You can't disable your own account.",
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Disable user?'),
                                      content: Text(
                                        'Are you sure you want to disable '
                                        '${p.fullName.isNotEmpty ? p.fullName : (hasUsername ? '@${p.username!.trim()}' : p.email)}?\n'
                                        'They will not be able to sign in.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Disable'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (!confirm) return;
                              await RoleService.instance.setDisabled(
                                p.id,
                                true,
                              );
                              if (context.mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('User disabled'),
                                  ),
                                );
                              }
                            } else if (value == 'toggle:enable') {
                              if (isSelf) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "You can't enable your own account here.",
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              await RoleService.instance.setDisabled(
                                p.id,
                                false,
                              );
                              if (context.mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('User enabled')),
                                );
                              }
                            } else if (value == 'verification:approve') {
                              try {
                                await VerificationService.instance
                                    .approveVerification(p.id);
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Verification approved'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to approve: $e'),
                                    ),
                                  );
                                }
                              }
                            } else if (value == 'verification:reject') {
                              final reason = await showDialog<String>(
                                context: context,
                                builder: (ctx) {
                                  final controller = TextEditingController();
                                  return AlertDialog(
                                    title: const Text('Reject Verification'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Reject verification for ${p.fullName.isNotEmpty ? p.fullName : p.email}?',
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: controller,
                                          decoration: const InputDecoration(
                                            labelText: 'Reason for rejection',
                                            hintText:
                                                'Documents unclear, expired, etc.',
                                          ),
                                          maxLines: 3,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(
                                          ctx,
                                        ).pop(controller.text.trim()),
                                        child: const Text('Reject'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (reason != null && reason.isNotEmpty) {
                                try {
                                  await VerificationService.instance
                                      .rejectVerification(p.id, reason);
                                  if (context.mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Verification rejected'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to reject: $e'),
                                      ),
                                    );
                                  }
                                }
                              }
                            } else if (value == 'verification:view') {
                              await _showVerificationDocuments(p);
                            }
                            await _refresh();
                          },
                          itemBuilder: (ctx) => [
                            CheckedPopupMenuItem<String>(
                              value: 'role:user',
                              checked: p.role == 'user',
                              enabled: !_loading && !isSelf,
                              child: const Text('Role: User'),
                            ),
                            CheckedPopupMenuItem<String>(
                              value: 'role:staff',
                              checked: p.role == 'staff',
                              enabled: !_loading && !isSelf,
                              child: const Text('Role: Staff'),
                            ),
                            // Intentionally omit 'Role: Admin' for safety.
                            const PopupMenuDivider(),
                            if (p.role == 'admin')
                              PopupMenuItem<String>(
                                enabled: false,
                                child: const Text(
                                  'Disable user (not allowed for admins)',
                                ),
                              )
                            else if (p.disabled == true)
                              PopupMenuItem<String>(
                                value: 'toggle:enable',
                                enabled: !_loading && !isSelf,
                                child: const Text('Enable user'),
                              )
                            else
                              PopupMenuItem<String>(
                                value: 'toggle:disable',
                                enabled: !_loading && !isSelf,
                                child: const Text('Disable user'),
                              ),
                            // Verification actions
                            if (p.verificationStatus == 'pending' ||
                                p.verificationDocuments != null) ...[
                              const PopupMenuDivider(),
                              if (p.verificationDocuments != null)
                                PopupMenuItem<String>(
                                  value: 'verification:view',
                                  enabled: !_loading,
                                  child: const Text('View Documents'),
                                ),
                              if (p.verificationStatus == 'pending') ...[
                                PopupMenuItem<String>(
                                  value: 'verification:approve',
                                  enabled: !_loading,
                                  child: const Text('Approve Verification'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'verification:reject',
                                  enabled: !_loading,
                                  child: const Text('Reject Verification'),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
                _buildPagination(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        final roleDropdown = DropdownButton<String?>(
          value: _roleFilter,
          hint: const Text('All roles'),
          items: const <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(value: null, child: Text('All roles')),
            DropdownMenuItem<String?>(value: 'user', child: Text('User')),
            DropdownMenuItem<String?>(value: 'staff', child: Text('Staff')),
            DropdownMenuItem<String?>(value: 'admin', child: Text('Admin')),
          ],
          onChanged: (v) async {
            _roleFilter = v;
            _page = 1;
            await _refresh();
          },
        );
        final searchField = TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by name, email, or username',
          ),
          onChanged: (v) async {
            _search = v;
            _page = 1;
            await _refresh();
          },
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (narrow) ...[
              searchField,
              const SizedBox(height: 12),
              roleDropdown,
            ] else
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  roleDropdown,
                ],
              ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: _sortBy,
                    items: const [
                      DropdownMenuItem(
                        value: 'created_at',
                        child: Text('Newest'),
                      ),
                      DropdownMenuItem(value: 'full_name', child: Text('Name')),
                      DropdownMenuItem(value: 'email', child: Text('Email')),
                      DropdownMenuItem(value: 'role', child: Text('Role')),
                    ],
                    onChanged: (v) async {
                      _sortBy = v ?? 'created_at';
                      await _refresh();
                    },
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Ascending'),
                    selected: _ascending,
                    onSelected: (v) async {
                      _ascending = v;
                      await _refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricsRow() {
    final total =
        (_metrics['user'] ?? 0) +
        (_metrics['staff'] ?? 0) +
        (_metrics['admin'] ?? 0);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metricChip(Icons.people, 'Total', total),
        _metricChip(Icons.person_outline, 'Users', _metrics['user'] ?? 0),
        _metricChip(
          Icons.medical_services_outlined,
          'Staff',
          _metrics['staff'] ?? 0,
        ),
        _metricChip(
          Icons.admin_panel_settings_outlined,
          'Admins',
          _metrics['admin'] ?? 0,
        ),
      ],
    );
  }

  Widget _metricChip(IconData icon, String label, int value) {
    return Chip(avatar: Icon(icon, size: 16), label: Text('$label: $value'));
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _page > 1 && !_loading
                ? () async {
                    _page -= 1;
                    await _refresh();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Prev'),
          ),
          const SizedBox(width: 12),
          Text('Page $_page'),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _hasNext && !_loading
                ? () async {
                    _page += 1;
                    await _refresh();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  String _initialFor(UserProfile p) {
    final source = (p.fullName.isNotEmpty ? p.fullName : p.email).trim();
    if (source.isEmpty) return '?';
    final ch = source[0];
    return ch.toUpperCase();
  }

  Future<void> _showVerificationDocuments(UserProfile profile) async {
    if (profile.verificationDocuments == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No verification documents found')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verification Documents - ${profile.fullName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${profile.verificationStatus ?? 'Unknown'}'),
              if (profile.verificationSubmittedAt != null)
                Text(
                  'Submitted: ${profile.verificationSubmittedAt!.toLocal().toString().split('.')[0]}',
                ),
              const SizedBox(height: 16),
              const Text(
                'Documents:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (profile.verificationDocuments!.selfieUrl != null) ...[
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Selfie'),
                  trailing: const Icon(Icons.visibility),
                  onTap: () async {
                    final path = profile.verificationDocuments!.selfieUrl!;
                    await _showDocumentViewer('Selfie', path);
                  },
                ),
              ],
              if (profile.verificationDocuments!.idDocumentUrl != null) ...[
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Government ID'),
                  trailing: const Icon(Icons.visibility),
                  onTap: () async {
                    final path = profile.verificationDocuments!.idDocumentUrl!;
                    await _showDocumentViewer('Government ID', path);
                  },
                ),
              ],
              if (profile.verificationDocuments!.proofOfResidenceUrl !=
                  null) ...[
                ListTile(
                  leading: const Icon(Icons.home),
                  title: const Text('Proof of Residence'),
                  trailing: const Icon(Icons.visibility),
                  onTap: () async {
                    final path =
                        profile.verificationDocuments!.proofOfResidenceUrl!;
                    await _showDocumentViewer('Proof of Residence', path);
                  },
                ),
              ],
              if (profile.verificationDocuments!.rejectionReason != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Rejection Reason:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(profile.verificationDocuments!.rejectionReason!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (profile.verificationStatus == 'pending') ...[
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await VerificationService.instance.approveVerification(
                    profile.id,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification approved')),
                    );
                    await _refresh();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to approve: $e')),
                    );
                  }
                }
              },
              child: const Text('Approve'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final reason = await showDialog<String>(
                  context: context,
                  builder: (ctx) {
                    final controller = TextEditingController();
                    return AlertDialog(
                      title: const Text('Reject Verification'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Please provide a reason for rejection:'),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              hintText: 'Documents unclear, expired, etc.',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(controller.text.trim()),
                          child: const Text('Reject'),
                        ),
                      ],
                    );
                  },
                );
                if (reason != null && reason.isNotEmpty) {
                  try {
                    await VerificationService.instance.rejectVerification(
                      profile.id,
                      reason,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification rejected')),
                      );
                      await _refresh();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to reject: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Reject'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDocumentViewer(String title, String storagePath) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: FutureBuilder<String>(
            future: VerificationService.instance.getDocumentSignedUrl(
              storagePath,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 600,
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  width: 600,
                  child: Text('Failed to load document: ${snapshot.error}'),
                );
              }
              final url = snapshot.data!;
              return SizedBox(
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
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
