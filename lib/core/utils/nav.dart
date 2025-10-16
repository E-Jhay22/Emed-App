import 'package:flutter/material.dart';
import '../widgets/role_scope.dart';

/// Navigation helpers that preserve RoleScope.
class Nav {
  static String _roleOf(BuildContext context) => RoleScope.of(context);

  static Future<T?> pushWithRole<T>(BuildContext context, Widget page) {
    final role = _roleOf(context);
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => RoleScope(role: role, child: page),
      ),
    );
  }

  static Future<T?> pushBuilderWithRole<T>(
    BuildContext context,
    WidgetBuilder builder,
  ) {
    final role = _roleOf(context);
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (ctx) => RoleScope(role: role, child: builder(ctx)),
      ),
    );
  }

  static Future<T?> pushReplacementWithRole<T>(
    BuildContext context,
    Widget page,
  ) {
    final role = _roleOf(context);
    return Navigator.of(context).pushReplacement<T, T>(
      MaterialPageRoute(
        builder: (_) => RoleScope(role: role, child: page),
      ),
    );
  }

  static Future<T?> pushAndRemoveUntilWithRole<T>(
    BuildContext context,
    Widget page,
    RoutePredicate predicate,
  ) {
    final role = _roleOf(context);
    return Navigator.of(context).pushAndRemoveUntil<T>(
      MaterialPageRoute(
        builder: (_) => RoleScope(role: role, child: page),
      ),
      predicate,
    );
  }
}
