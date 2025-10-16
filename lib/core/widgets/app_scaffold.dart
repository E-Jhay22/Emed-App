import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/appointments/presentation/appointment_list_page.dart';
import '../../features/announcements/presentation/announcement_list_page.dart';
import '../../features/inventory/presentation/inventory_list_page.dart';
import '../../features/inventory/presentation/receive_stock_page.dart';
import '../../features/inventory/presentation/dispense_medicines_page.dart';
import '../../features/inventory/presentation/adjust_stock_page.dart';
import '../../features/inventory/presentation/inventory_reports_page.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import 'role_scope.dart';
import '../../services/auth_service.dart';
import '../../features/auth/presentation/login_page.dart';
import '../utils/nav.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final String? role;
  final String? currentLabel;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.role,
    this.currentLabel,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRole = role ?? RoleScope.of(context);
    final items = _menuItems
        .where((m) => m.roles.contains(effectiveRole))
        .toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: Text(title),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              FutureBuilder(
                future: AuthService.instance.getProfile(),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final firstName = (profile?.firstName ?? '').trim();
                  String fallback = '';
                  final full = (profile?.fullName ?? '').trim();
                  if (full.isNotEmpty) {
                    final parts = full.split(' ');
                    if (parts.isNotEmpty) fallback = parts.first.trim();
                  }
                  final greetingName = firstName.isNotEmpty
                      ? firstName
                      : fallback;
                  final hello = greetingName.isNotEmpty
                      ? 'Hello, $greetingName'
                      : 'Hello';
                  return DrawerHeader(
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          hello,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Menu'),
                      ],
                    ),
                  );
                },
              ),
              for (final m in items)
                ListTile(
                  leading: Icon(m.icon),
                  title: Text(m.label),
                  selected: currentLabel == m.label,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentLabel == m.label) return;
                    final nav = Navigator.of(context);
                    nav.popUntil((route) => route.isFirst);
                    if (m.label == 'Dashboard') return;
                    Nav.pushWithRole(context, m.builder(effectiveRole));
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await AuthService.instance.signOut();
                  if (!context.mounted) return;
                  Nav.pushAndRemoveUntilWithRole(
                    context,
                    const LoginPage(),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final List<String> roles; // allowed roles
  final Widget Function(String role) builder; // builds destination page

  _MenuItem({
    required this.label,
    required this.icon,
    required this.roles,
    required this.builder,
  });
}

final List<_MenuItem> _menuItems = [
  _MenuItem(
    label: 'Dashboard',
    icon: Icons.dashboard,
    roles: ['user', 'staff', 'admin'],
    builder: (role) => RoleScope(
      role: role,
      child: DashboardPage(role: role),
    ),
  ),
  _MenuItem(
    label: 'Appointments',
    icon: Icons.event,
    roles: ['user', 'staff', 'admin'],
    builder: (role) =>
        RoleScope(role: role, child: const AppointmentListPage()),
  ),
  _MenuItem(
    label: 'Announcements',
    icon: Icons.campaign,
    roles: ['user', 'staff', 'admin'],
    builder: (role) =>
        RoleScope(role: role, child: const AnnouncementListPage()),
  ),
  _MenuItem(
    label: 'Inventory',
    icon: Icons.inventory,
    roles: ['staff', 'admin'],
    builder: (role) => RoleScope(role: role, child: const InventoryListPage()),
  ),
  _MenuItem(
    label: 'Receive Stock',
    icon: Icons.move_to_inbox,
    roles: ['staff', 'admin'],
    builder: (role) => RoleScope(role: role, child: const ReceiveStockPage()),
  ),
  _MenuItem(
    label: 'Dispense Medicines',
    icon: Icons.local_hospital,
    roles: ['staff', 'admin'],
    builder: (role) =>
        RoleScope(role: role, child: const DispenseMedicinesPage()),
  ),
  _MenuItem(
    label: 'Adjust Stock',
    icon: Icons.tune,
    roles: ['staff', 'admin'],
    builder: (role) => RoleScope(role: role, child: const AdjustStockPage()),
  ),
  _MenuItem(
    label: 'Inventory Reports',
    icon: Icons.assignment,
    roles: ['staff', 'admin'],
    builder: (role) =>
        RoleScope(role: role, child: const InventoryReportsPage()),
  ),
  _MenuItem(
    label: 'Admin',
    icon: Icons.admin_panel_settings,
    roles: ['admin'],
    builder: (role) => RoleScope(role: role, child: const AdminPage()),
  ),
  _MenuItem(
    label: 'Profile',
    icon: Icons.person,
    roles: ['user', 'staff', 'admin'],
    builder: (role) => RoleScope(role: role, child: const ProfilePage()),
  ),
];
