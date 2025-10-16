import 'package:flutter/material.dart';
import '../../../../models/appointment.dart';
import '../../../../services/appointment_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';
import 'widgets/appointment_chat_widget.dart';

class AppointmentDetailPage extends StatefulWidget {
  final Appointment appointment;
  const AppointmentDetailPage({super.key, required this.appointment});

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  bool _loading = false;
  late Appointment _apt;

  @override
  void initState() {
    super.initState();
    _apt = widget.appointment;
  }

  Future<void> _schedule() async {
    final staff = SupabaseService.instance.currentUser?.id ?? 'staff-unknown';
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;
    if (!mounted) return;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    ).toUtc();
    setState(() => _loading = true);
    try {
      await AppointmentService.instance.scheduleAppointment(
        _apt.id,
        combined,
        staff,
      );
      if (!mounted) return;
      String? staffName;
      try {
        final profile = await AuthService.instance.getProfile(userId: staff);
        staffName = profile?.fullName;
      } catch (_) {}
      // update UI fast
      setState(() {
        _apt = Appointment(
          id: _apt.id,
          userId: _apt.userId,
          staffId: staff,
          requestedAt: _apt.requestedAt,
          scheduledAt: combined,
          status: 'scheduled',
          notes: _apt.notes,
          requestedByName: _apt.requestedByName,
          scheduledByName: staffName ?? _apt.scheduledByName,
        );
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment scheduled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Schedule failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    final a = _apt;
    final isScheduled = a.scheduledAt != null;
    final statusColor = isScheduled
        ? Colors.green
        : Theme.of(context).colorScheme.primary;
    return AppScaffold(
      title: 'Appointment',
      role: role,
      currentLabel: 'Appointments',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(Icons.event, size: 72, color: statusColor),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            'Appointment',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusPill(text: a.status, color: statusColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(
                        label: 'Requested',
                        value: a.requestedAt.toLocal().toString().substring(
                          0,
                          16,
                        ),
                      ),
                      if ((a.requestedByName ?? '').isNotEmpty)
                        _InfoChip(
                          label: 'Requested by',
                          value: a.requestedByName!,
                        ),
                      _InfoChip(
                        label: 'Scheduled',
                        value: isScheduled
                            ? a.scheduledAt!.toLocal().toString().substring(
                                0,
                                16,
                              )
                            : '-',
                      ),
                      if (isScheduled && (a.scheduledByName ?? '').isNotEmpty)
                        _InfoChip(
                          label: 'Scheduled by',
                          value: a.scheduledByName!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    a.notes ?? '-',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Text('Chat', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AppointmentChatWidget(appointment: a),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        if (_shouldShowSchedule(role, isScheduled))
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _schedule,
                              icon: const Icon(Icons.schedule),
                              label: const Text('Schedule'),
                            ),
                          ),
                        if (_shouldShowSchedule(role, isScheduled))
                          const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              isScheduled
                                  ? Icons.cancel_schedule_send
                                  : Icons.cancel,
                            ),
                            label: Text(
                              isScheduled ? 'Request Cancel' : 'Cancel Request',
                            ),
                            onPressed: () =>
                                _onCancelPressed(role, isScheduled),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCancelPressed(String role, bool isScheduled) async {
    final reason = await _promptReason(
      context,
      title: isScheduled
          ? 'Request Cancellation'
          : 'Cancel Appointment Request',
      hint: 'Please provide a reason',
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (!isScheduled) {
        // User can cancel their requested appointment; staff can also cancel via staff endpoint
        if (role == 'staff' || role == 'admin') {
          final staff = SupabaseService.instance.currentUser?.id;
          if (staff == null) throw Exception('Not authenticated');
          await AppointmentService.instance.cancelByStaff(
            appointmentId: _apt.id,
            staffId: staff,
            reason: reason,
          );
        } else {
          await AppointmentService.instance.cancelRequestedByUser(
            appointmentId: _apt.id,
            reason: reason,
          );
        }
      } else {
        // Scheduled: user requests cancellation; staff/admin immediately cancel
        if (role == 'staff' || role == 'admin') {
          final staff = SupabaseService.instance.currentUser?.id;
          if (staff == null) throw Exception('Not authenticated');
          await AppointmentService.instance.cancelByStaff(
            appointmentId: _apt.id,
            staffId: staff,
            reason: reason,
          );
        } else {
          await AppointmentService.instance.requestCancelScheduledByUser(
            appointmentId: _apt.id,
            reason: reason,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isScheduled ? 'Cancellation request sent' : 'Appointment cancelled',
          ),
        ),
      );
      // Optimistic UI update
      setState(() {
        if (role == 'staff' || role == 'admin') {
          _apt = Appointment(
            id: _apt.id,
            userId: _apt.userId,
            staffId: _apt.staffId,
            requestedAt: _apt.requestedAt,
            scheduledAt: _apt.scheduledAt,
            status: 'cancelled',
            notes: _apt.notes,
            requestedByName: _apt.requestedByName,
            scheduledByName: _apt.scheduledByName,
            cancelledAt: DateTime.now().toUtc(),
            cancelledBy: SupabaseService.instance.currentUser?.id,
            cancelRequestReason: null,
            cancelRequestAt: null,
          );
        } else {
          _apt = Appointment(
            id: _apt.id,
            userId: _apt.userId,
            staffId: _apt.staffId,
            requestedAt: _apt.requestedAt,
            scheduledAt: _apt.scheduledAt,
            status: _apt.scheduledAt == null ? 'cancelled' : _apt.status,
            notes: _apt.notes,
            requestedByName: _apt.requestedByName,
            scheduledByName: _apt.scheduledByName,
            cancelledAt: _apt.scheduledAt == null
                ? DateTime.now().toUtc()
                : _apt.cancelledAt,
            cancelledBy: _apt.scheduledAt == null
                ? _apt.userId
                : _apt.cancelledBy,
            cancelRequestReason: _apt.scheduledAt != null ? reason : null,
            cancelRequestAt: _apt.scheduledAt != null
                ? DateTime.now().toUtc()
                : null,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

bool _shouldShowSchedule(String role, bool isScheduled) {
  if (isScheduled) return false;
  return role == 'staff' || role == 'admin';
}

Future<String?> _promptReason(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      );
    },
  );
}
