import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import 'supabase_service.dart';

class AnnouncementService {
  AnnouncementService._privateConstructor();
  static final AnnouncementService instance =
      AnnouncementService._privateConstructor();

  final _client = SupabaseService.instance.client;

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

  Stream<List<Announcement>> streamAnnouncements({
    Duration pollInterval = const Duration(seconds: 5),
  }) async* {
    try {
      final controller = StreamController<List<Announcement>>();
      final res = await _client
          .from('announcements')
          .select('*, profiles!announcements_created_by_fkey(full_name)');
      final items = _rowsFrom(
        res,
      ).map((e) => Announcement.fromJson(e)).toList();
      controller.add(items);

      _client.channel('public:announcements').on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: '*', schema: 'public', table: 'announcements'),
        (payload, [ref]) async {
          final res2 = await _client
              .from('announcements')
              .select('*, profiles!announcements_created_by_fkey(full_name)');
          final items2 = _rowsFrom(
            res2,
          ).map((e) => Announcement.fromJson(e)).toList();
          controller.add(items2);
        },
      ).subscribe();

      yield* controller.stream;
    } catch (e) {
      // Polling fallback
      while (true) {
        final res = await _client.from('announcements').select();
        final list = _rowsFrom(
          res,
        ).map((e) => Announcement.fromJson(e)).toList();
        yield list;
        await Future.delayed(pollInterval);
      }
    }
  }

  Future<void> createAnnouncement(Announcement a) async {
    await _client.from('announcements').insert({
      'title': a.title,
      'body': a.body,
      'starts_at': a.startsAt?.toIso8601String(),
      'ends_at': a.endsAt?.toIso8601String(),
      'created_by': SupabaseService.instance.currentUser?.id,
    });
  }

  Future<void> updateAnnouncement(
    String id,
    Map<String, dynamic> changes,
  ) async {
    await _client.from('announcements').update(changes).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _client.from('announcements').delete().eq('id', id);
  }
}
