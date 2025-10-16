import 'package:flutter/material.dart';

/// Show child only if role is allowed.

class RoleGuard extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final String currentRole;

  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.currentRole = 'user',
  });

  @override
  Widget build(BuildContext context) {
    if (allowedRoles.contains(currentRole)) return child;
    return const SizedBox.shrink();
  }
}
