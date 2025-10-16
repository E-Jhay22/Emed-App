import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment.dart';
import '../models/appointment_message.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

class AppointmentService {
  AppointmentService._privateConstructor();
  static final AppointmentService instance =
      AppointmentService._privateConstructor();

  final _client = SupabaseService.instance.client;

  List<Appointment> _mapRowsToAppointments(
    Iterable<Map<String, dynamic>> rows,
  ) {
    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      if (map['user'] is Map && (map['user'] as Map)['name'] != null) {
        map['requested_by_name'] = (map['user'] as Map)['name'];
      }
      if (map['staff'] is Map && (map['staff'] as Map)['name'] != null) {
        map['scheduled_by_name'] = (map['staff'] as Map)['name'];
      }
      return Appointment.fromJson(map);
    }).toList();
  }

  List<Map<String, dynamic>> _rowsFrom(dynamic res) {
    if (res is List) {
      return res.cast<Map<String, dynamic>>();
    }
    try {
      final data = (res as dynamic).data;
      if (data is List) return data.cast<Map<String, dynamic>>();
    } catch (_) {}
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).cast<Map<String, dynamic>>();
    }
    return const <Map<String, dynamic>>[];
  }

  Stream<List<Appointment>> streamAppointmentsForUser(
    String userId, {
    Duration pollInterval = const Duration(seconds: 5),
  }) async* {
    try {
      final controller = StreamController<List<Appointment>>();
      final res = await _client
          .from('appointments')
          .select(
            '*, user:profiles!appointments_user_id_fkey(full_name), staff:profiles!appointments_staff_id_fkey(full_name)',
          )
          .eq('user_id', userId)
          .order('requested_at', ascending: false);
      final items = _mapRowsToAppointments(_rowsFrom(res));
      controller.add(items);

      _client.channel('public:appointments').on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: '*', schema: 'public', table: 'appointments'),
        (payload, [ref]) async {
          final res2 = await _client
              .from('appointments')
              .select(
                '*, user:profiles!appointments_user_id_fkey(full_name), staff:profiles!appointments_staff_id_fkey(full_name)',
              )
              .eq('user_id', userId)
              .order('requested_at', ascending: false);
          final items2 = _mapRowsToAppointments(_rowsFrom(res2));
          controller.add(items2);
        },
      ).subscribe();

      yield* controller.stream;
    } catch (e) {
      while (true) {
        final res = await _client
            .from('appointments')
            .select(
              '*, user:profiles!appointments_user_id_fkey(full_name), staff:profiles!appointments_staff_id_fkey(full_name)',
            )
            .eq('user_id', userId)
            .order('requested_at', ascending: false);
        final list = _mapRowsToAppointments(_rowsFrom(res));
        yield list;
        await Future.delayed(pollInterval);
      }
    }
  }

  /// Stream appointments visible to staff/admin (optionally filter by status)
  Stream<List<Appointment>> streamAllAppointments({
    String? statusFilter,
    Duration pollInterval = const Duration(seconds: 5),
  }) async* {
    try {
      final controller = StreamController<List<Appointment>>();
      dynamic query = _client
          .from('appointments')
          .select(
            '*, user:profiles!appointments_user_id_fkey(full_name), staff:profiles!appointments_staff_id_fkey(full_name)',
          )
          .order('requested_at', ascending: false);
      if (statusFilter != null && statusFilter.isNotEmpty) {
        query = query.eq('status', statusFilter);
      }
      final res = await query;
      controller.add(_mapRowsToAppointments(_rowsFrom(res)));

      _client.channel('public:appointments').on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: '*', schema: 'public', table: 'appointments'),
        (payload, [ref]) async {
          dynamic q2 = _client
              .from('appointments')
              .select(
                '*, user:profiles!appointments_user_id_fkey(full_name), staff:profiles!appointments_staff_id_fkey(full_name)',
              )
              .order('requested_at', ascending: false);
          if (statusFilter != null && statusFilter.isNotEmpty) {
            q2 = q2.eq('status', statusFilter);
          }
          final res2 = await q2;
          controller.add(_mapRowsToAppointments(_rowsFrom(res2)));
        },
      ).subscribe();

      yield* controller.stream;
    } catch (e) {
      while (true) {
        try {
          dynamic query = _client
              .from('appointments')
              .select(
                '*, user:profiles!appointments_user_id_fkey(full_name), staff:profiles!appointments_staff_id_fkey(full_name)',
              )
              .order('requested_at', ascending: false);
          if (statusFilter != null && statusFilter.isNotEmpty) {
            query = query.eq('status', statusFilter);
          }
          final res = await query;
          yield _mapRowsToAppointments(_rowsFrom(res));
        } catch (_) {
          yield const <Appointment>[];
        }
        await Future.delayed(pollInterval);
      }
    }
  }

  // ==========================
  // Cancellation operations
  // ==========================
  Future<void> cancelRequestedByUser({
    required String appointmentId,
    required String reason,
  }) async {
    await _client.rpc(
      'appointment_user_cancel_request',
      params: {'p_id': appointmentId, 'p_reason': reason},
    );
  }

  Future<void> requestCancelScheduledByUser({
    required String appointmentId,
    required String reason,
  }) async {
    await _client.rpc(
      'appointment_user_request_cancel_scheduled',
      params: {'p_id': appointmentId, 'p_reason': reason},
    );
  }

  Future<void> cancelByStaff({
    required String appointmentId,
    required String staffId,
    required String reason,
  }) async {
    await _client.rpc(
      'appointment_cancel',
      params: {
        'p_id': appointmentId,
        'p_reason': reason,
        'p_staff_id': staffId,
      },
    );
  }

  Future<void> requestAppointment(Appointment a) async {
    // Check if user is verified before allowing appointment creation
    final currentUser = await AuthService.instance.getProfile();
    if (currentUser?.verified != true) {
      throw Exception(
        'You must complete identity verification before requesting appointments. Please verify your identity in the Profile section.',
      );
    }

    // Insert respects legacy schemas while moving to requested_at/scheduled_at fields.
    // Note: RLS should allow user to insert their own request; server enforces defaults.
    final payload = {
      'user_id': SupabaseService.instance.currentUser?.id,
      'staff_id': a.staffId,
      'status': a.status,
      'requested_at': a.requestedAt.toIso8601String(),
      'scheduled_at': a.scheduledAt?.toIso8601String(),
      'notes': a.notes,
    };
    final legacyDate = a.requestedAt
        .toUtc()
        .toIso8601String()
        .split('T')
        .first; // YYYY-MM-DD
    try {
      // Backward-compat: some schemas still have NOT NULL column "date"
      await _client.from('appointments').insert({
        ...payload,
        'date': legacyDate,
      });
    } catch (e) {
      // If "date" column doesn't exist (42703), retry without it
      if (e is PostgrestException && e.code == '42703') {
        await _client.from('appointments').insert(payload);
      } else {
        rethrow;
      }
    }
  }

  Future<void> scheduleAppointment(
    String id,
    DateTime scheduledAt,
    String staffId,
  ) async {
    // Prefer SECURITY DEFINER RPC to make this RLS-safe. Fallback uses direct update
    // for older environments until the RPC is deployed.
    final legacyDate = scheduledAt
        .toUtc()
        .toIso8601String()
        .split('T')
        .first; // YYYY-MM-DD

    // Prefer RPC to bypass RLS with SECURITY DEFINER on server
    try {
      await _client.rpc(
        'appointment_schedule',
        params: {
          'p_id': id,
          'p_scheduled_at': scheduledAt.toIso8601String(),
          'p_staff_id': staffId,
        },
      );
      return;
    } catch (e) {
      // If RPC isn't deployed yet, fall back to direct update (may be blocked by RLS)
      final isMissingFn = e is PostgrestException && e.code == '42883';
      if (!isMissingFn) rethrow;
    }

    try {
      // Try setting legacy "date" too
      await _client
          .from('appointments')
          .update({
            'scheduled_at': scheduledAt.toIso8601String(),
            'staff_id': staffId,
            'status': 'scheduled',
            'date': legacyDate,
          })
          .eq('id', id);
    } catch (e) {
      if (e is PostgrestException && e.code == '42703') {
        await _client
            .from('appointments')
            .update({
              'scheduled_at': scheduledAt.toIso8601String(),
              'staff_id': staffId,
              'status': 'scheduled',
            })
            .eq('id', id);
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateAppointment(
    String id,
    Map<String, dynamic> changes,
  ) async {
    // Generic patch helper. Consider server procedures for sensitive state transitions.
    await _client.from('appointments').update(changes).eq('id', id);
  }

  // ============================================
  // Appointment Messaging System
  // ============================================

  /// Send a message for a specific appointment
  Future<String> sendAppointmentMessage(
    String appointmentId,
    String message,
  ) async {
    try {
      final result = await _client.rpc(
        'send_appointment_message',
        params: {
          'p_appointment_id': appointmentId,
          'p_message': message.trim(),
        },
      );

      return result as String; // Returns the message ID
    } catch (e) {
      // If RPC not found, fall back to direct insert (may be blocked by RLS)
      if (e is PostgrestException &&
          (e.code == 'PGRST202' || e.code == '42883' || e.code == '42702')) {
        try {
          final currentUser = AuthService.instance.currentUser;
          if (currentUser == null) throw Exception('Not authenticated');
          final profile = await AuthService.instance.getProfile();
          final senderRole = (profile?.role ?? 'user').toLowerCase();

          final insertPayload = {
            'appointment_id': appointmentId,
            'sender_id': currentUser.id,
            'sender_role': senderRole,
            'message': message.trim(),
          };

          final inserted = await _client
              .from('appointment_messages')
              .insert(insertPayload)
              .select('id')
              .single();
          return inserted['id'] as String;
        } catch (inner) {
          if (inner is PostgrestException && inner.code == '42P01') {
            throw Exception(
              'Messaging backend not installed (missing table appointment_messages). Please run the database migration.',
            );
          }
          if (inner is PostgrestException &&
              (inner.code == '42501' || inner.code == 'PGRST301')) {
            throw Exception(
              'Permission denied by RLS while sending message. Ensure policies or install the SECURITY DEFINER RPCs.',
            );
          }
          throw Exception('Failed to send message: $inner');
        }
      }
      throw Exception('Failed to send message: $e');
    }
  }

  /// Get all messages for a specific appointment
  Future<List<AppointmentMessage>> getAppointmentMessages(
    String appointmentId,
  ) async {
    try {
      final List<dynamic> result = await _client.rpc(
        'get_appointment_messages',
        params: {'p_appointment_id': appointmentId},
      );

      return result
          .map((e) => AppointmentMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If RPC not found, fall back to direct select from table
      if (e is PostgrestException &&
          (e.code == 'PGRST202' || e.code == '42883' || e.code == '42702')) {
        try {
          final List<dynamic> rows = await _client
              .from('appointment_messages')
              .select('*')
              .eq('appointment_id', appointmentId)
              .order('created_at');
          return rows
              .map(
                (e) => AppointmentMessage.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        } catch (inner) {
          if (inner is PostgrestException && inner.code == '42P01') {
            throw Exception(
              'Messaging backend not installed (missing table appointment_messages). Please run the database migration.',
            );
          }
          if (inner is PostgrestException &&
              (inner.code == '42501' || inner.code == 'PGRST301')) {
            throw Exception(
              'Permission denied by RLS while loading messages. Ensure policies or install the SECURITY DEFINER RPCs.',
            );
          }
          throw Exception('Failed to load messages: $inner');
        }
      }
      throw Exception('Failed to load messages: $e');
    }
  }

  /// Stream messages for real-time updates
  Stream<List<AppointmentMessage>> streamAppointmentMessages(
    String appointmentId,
  ) {
    return Stream.periodic(const Duration(seconds: 2))
        .asyncMap((_) => getAppointmentMessages(appointmentId))
        .distinct(
          (prev, curr) =>
              prev.length == curr.length &&
              prev.isNotEmpty &&
              curr.isNotEmpty &&
              prev.last.id == curr.last.id,
        );
  }

  /// Check if current user can message this appointment
  Future<bool> canMessageAppointment(String appointmentId) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return false;

    try {
      final profile = await AuthService.instance.getProfile();

      // Staff and admins can message any appointment
      if (profile?.role == 'staff' || profile?.role == 'admin') {
        return true;
      }

      // Users can message their own appointments
      final List<dynamic> appointment = await _client
          .from('appointments')
          .select('user_id')
          .eq('id', appointmentId)
          .eq('user_id', currentUser.id)
          .limit(1);

      return appointment.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
