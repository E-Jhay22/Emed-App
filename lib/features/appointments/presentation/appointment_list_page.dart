import 'package:flutter/material.dart';
import '../../../../services/appointment_service.dart';
import '../../../../models/appointment.dart';
import 'appointment_detail_page.dart';
import 'appointment_request_page.dart';
import '../../../../services/supabase_service.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/utils/nav.dart';

class AppointmentListPage extends StatefulWidget {
  const AppointmentListPage({super.key});

  @override
  State<AppointmentListPage> createState() => _AppointmentListPageState();
}

class _AppointmentListPageState extends State<AppointmentListPage> {
  late final String? _userId;
  late Stream<List<Appointment>> _stream;

  @override
  void initState() {
    super.initState();
    _userId = SupabaseService.instance.currentUser?.id;
    _stream = AppointmentService.instance.streamAppointmentsForUser(
      _userId ?? '',
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _stream = AppointmentService.instance.streamAppointmentsForUser(
        _userId ?? '',
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Appointments',
      currentLabel: 'Appointments',
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Nav.pushWithRole(context, const AppointmentRequestPage()),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 64),
                children: const [Center(child: Text('No appointments'))],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = items[index];
                final isScheduled = a.scheduledAt != null;
                final color = isScheduled
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary;
                final requested = a.requestedAt.toLocal().toString().substring(
                  0,
                  16,
                );
                final scheduled = isScheduled
                    ? a.scheduledAt!.toLocal().toString().substring(0, 16)
                    : '-';
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Nav.pushWithRole(
                    context,
                    AppointmentDetailPage(appointment: a),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.event, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointment',
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Requested: $requested\nScheduled: $scheduled',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            a.status,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/* Original FAB preserved for reference
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AppointmentRequestPage()),
        ),
        child: const Icon(Icons.add),
      ),
*/
