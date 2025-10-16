import 'package:flutter/widgets.dart';

class RoleScope extends InheritedWidget {
  final String role; // 'admin' | 'staff' | 'user'

  const RoleScope({super.key, required this.role, required super.child});

  static String of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RoleScope>();
    return scope?.role ?? 'user';
  }

  @override
  bool updateShouldNotify(RoleScope oldWidget) => oldWidget.role != role;
}
