import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../models/announcement.dart';
import '../../../models/appointment.dart';
import '../../../models/inventory_item.dart';
import '../../../services/announcement_service.dart';
import '../../../services/appointment_service.dart';
import '../../../services/inventory_service.dart';
import '../../../services/supabase_service.dart';
import '../../announcements/presentation/announcement_detail_page.dart';
import '../../appointments/presentation/appointment_detail_page.dart';
// go to list
import '../../inventory/presentation/inventory_list_page.dart';
import '../../../core/utils/nav.dart';

class DashboardPage extends StatefulWidget {
  final String role;
  const DashboardPage({super.key, this.role = 'user'});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final DateTime _selectedDate = DateTime.now();

  // data streams
  late final Stream<List<Announcement>> _announcementsStream;
  late final Stream<List<Appointment>> _appointmentsStream;
  late final Stream<List<InventoryItem>> _inventoryStream;
  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // user id
    _userId = SupabaseService.instance.currentUser?.id;
    _announcementsStream = AnnouncementService.instance.streamAnnouncements();
    _appointmentsStream = _userId != null
        ? AppointmentService.instance.streamAppointmentsForUser(_userId!)
        : const Stream.empty();
    _inventoryStream = InventoryService.instance.streamInventory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger a rebuild to ensure latest inventory/streams
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    // only future days with items

    return AppScaffold(
      title: 'Dashboard',
      role: widget.role,
      currentLabel: 'Dashboard',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Announcement>>(
              stream: _announcementsStream,
              builder: (context, annSnapshot) {
                return StreamBuilder<List<Appointment>>(
                  stream: _appointmentsStream,
                  builder: (context, appSnapshot) {
                    return StreamBuilder<List<InventoryItem>>(
                      stream: _inventoryStream,
                      builder: (context, invSnapshot) {
                        // merge by date
                        final activitiesByDate = <DateTime, List<Activity>>{};
                        // announcements
                        if (annSnapshot.hasData) {
                          for (final a in annSnapshot.data!) {
                            // group by createdAt
                            final date = a.createdAt ?? today;
                            final key = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                            activitiesByDate
                                .putIfAbsent(key, () => [])
                                .add(
                                  Activity(
                                    subject: 'Announcement',
                                    name: a.title,
                                    points: null,
                                    // store createdAt
                                    due: a.createdAt ?? today,
                                    icon: Icons.campaign,
                                    color: Colors.purple,
                                    link: '',
                                    data: a,
                                  ),
                                );
                          }
                        }
                        // appointments
                        if (appSnapshot.hasData) {
                          for (final appt in appSnapshot.data!) {
                            final date = appt.scheduledAt ?? appt.requestedAt;
                            final key = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                            activitiesByDate
                                .putIfAbsent(key, () => [])
                                .add(
                                  Activity(
                                    subject: 'Appointment',
                                    name: appt.status,
                                    points: null,
                                    due: date,
                                    icon: Icons.event,
                                    color: Colors.teal,
                                    link: '',
                                    data: appt,
                                  ),
                                );
                          }
                        }
                        // low stock
                        if (invSnapshot.hasData) {
                          for (final item in invSnapshot.data!) {
                            if (item.minQuantity != null &&
                                item.quantity <= item.minQuantity!) {
                              final key = today;
                              activitiesByDate
                                  .putIfAbsent(key, () => [])
                                  .add(
                                    Activity(
                                      subject: 'Inventory',
                                      name: '${item.name} low stock',
                                      points: null,
                                      // no due, use today
                                      due: today,
                                      icon: Icons.inventory,
                                      color: Colors.red,
                                      link: '',
                                      data: item,
                                    ),
                                  );
                            }
                          }
                        }

                        final todayActivities = activitiesByDate[today] ?? [];

                        // only future with items
                        final futureDaysWithItems =
                            activitiesByDate.keys
                                .where((d) => d.isAfter(today))
                                .toList()
                              ..sort((a, b) => a.compareTo(b));

                        return RefreshIndicator(
                          onRefresh: () async {
                            // On pull-to-refresh, rebuild to pick up latest streams
                            setState(() {});
                            await Future<void>.delayed(
                              const Duration(milliseconds: 200),
                            );
                          },
                          child: ListView(
                            children: [
                              _buildDateNavBar(today, isWide),
                              const SizedBox(height: 16),
                              _buildTodaySection(today, todayActivities),
                              if (futureDaysWithItems.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                for (final day in futureDaysWithItems)
                                  _buildDaySection(
                                    day,
                                    activitiesByDate[day] ?? const [],
                                  ),
                              ],
                              if (futureDaysWithItems.isEmpty) ...[
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'No more items to show',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateNavBar(DateTime today, bool isWide) {
    return Center(
      child: Text(
        DateFormat.yMMMMd().format(_selectedDate),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildTodaySection(DateTime today, List<Activity> acts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMMd().format(today),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (acts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Nothing planned yet',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ...acts.map((a) => _buildActivityCard(a)),
      ],
    );
  }

  Widget _buildDaySection(DateTime day, List<Activity> acts) {
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            DateFormat.yMMMMd().format(day),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isToday ? Theme.of(context).colorScheme.primary : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (acts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Nothing planned yet',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ...acts.map((a) => _buildActivityCard(a)),
      ],
    );
  }

  Widget _buildActivityCard(Activity a) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: () => _openActivityDetails(a),
        leading: Container(
          width: 8,
          height: 48,
          decoration: BoxDecoration(
            color: a.color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Row(
          children: [
            Icon(a.icon, color: a.color, size: 20),
            const SizedBox(width: 8),
            Text(a.subject, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.name),
            if (a.points != null)
              Text('Points: ${a.points}', style: const TextStyle(fontSize: 12)),
            // hide due label
            if (a.subject != 'Announcement' && a.subject != 'Inventory')
              Text('Due: ${DateFormat.jm().format(a.due)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Details',
          onPressed: () => _openActivityDetails(a),
        ),
      ),
    );
  }

  void _openActivityDetails(Activity a) async {
    final navigator = Navigator.of(context);
    final data = a.data;
    try {
      if (data is Announcement) {
        await navigator.push<Announcement?>(
          MaterialPageRoute(
            builder: (_) => AnnouncementDetailPage(announcement: data),
          ),
        );
      } else if (data is Appointment) {
        await Nav.pushWithRole<Appointment?>(
          context,
          AppointmentDetailPage(appointment: data),
        );
      } else if (data is InventoryItem) {
        // go to inventory list
        await Nav.pushWithRole(context, const InventoryListPage());
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No details available for this item')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open details: $e')));
      }
    }
  }

  // no empty day card
}

class Activity {
  final String subject;
  final String name;
  final int? points;
  final DateTime due;
  final IconData icon;
  final Color color;
  final String link;
  final Object? data;
  Activity({
    required this.subject,
    required this.name,
    this.points,
    required this.due,
    required this.icon,
    required this.color,
    required this.link,
    this.data,
  });
}
