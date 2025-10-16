import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';
import '../models/inventory_txn.dart';
import 'supabase_service.dart';
import 'package:image_picker/image_picker.dart';

class InventoryService {
  InventoryService._privateConstructor();
  static final InventoryService instance =
      InventoryService._privateConstructor();

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

  /// Stream inventory (realtime or polling)
  Stream<List<InventoryItem>> streamInventory({
    Duration pollInterval = const Duration(seconds: 5),
  }) async* {
    // Try to use realtime subscription
    try {
      final controller = StreamController<List<InventoryItem>>();
      // first load
      final res = await _client.from('inventory').select();
      final items = _rowsFrom(
        res,
      ).map((e) => InventoryItem.fromJson(e)).toList();
      controller.add(items);

      _client.channel('public:inventory').on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: '*', schema: 'public', table: 'inventory'),
        (payload, [ref]) async {
          final res2 = await _client.from('inventory').select();
          final items2 = _rowsFrom(
            res2,
          ).map((e) => InventoryItem.fromJson(e)).toList();
          controller.add(items2);
        },
      ).subscribe();

      yield* controller.stream;
    } catch (e) {
      // polling fallback
      while (true) {
        final res = await _client.from('inventory').select();
        final list = _rowsFrom(
          res,
        ).map((e) => InventoryItem.fromJson(e)).toList();
        yield list;
        await Future.delayed(pollInterval);
      }
    }
  }

  Future<void> addItem(InventoryItem item) async {
    await _client.rpc(
      'inventory_create_item',
      params: {
        'p_name': item.name,
        'p_description': item.description,
        'p_category': item.category,
        'p_min_quantity': item.minQuantity,
        'p_initial_quantity': item.quantity,
        'p_notes': null,
      },
    );
  }

  /// Create item via RPC (returns id)
  Future<String> createItem({
    required String name,
    String? description,
    String? category,
    int? minQuantity,
    int initialQuantity = 0,
  }) async {
    final res = await _client.rpc(
      'inventory_create_item',
      params: {
        'p_name': name,
        'p_description': description,
        'p_category': category,
        'p_min_quantity': minQuantity,
        'p_initial_quantity': initialQuantity,
        'p_notes': null,
      },
    );
    // read id from response
    if (res is Map && res['id'] is String) return res['id'] as String;
    if (res is String && res.isNotEmpty) return res;
    if (res is List && res.isNotEmpty) {
      final first = res.first;
      if (first is Map && first['id'] is String) return first['id'] as String;
    }
    throw Exception('Create item did not return id');
  }

  /// Create + optional image + receive
  Future<String> createItemAndReceive({
    required String name,
    String? description,
    String? category,
    int? minQuantity,
    required int quantity,
    String? notes,
    XFile? image,
  }) async {
    final itemId = await createItem(
      name: name,
      description: description,
      category: category,
      minQuantity: minQuantity,
      initialQuantity: 0,
    );
    if (image != null) {
      try {
        await uploadAndSetItemImage(itemId: itemId, xfile: image);
      } catch (_) {
        // ignore image failure
      }
    }
    await receiveStock(itemId: itemId, quantity: quantity, notes: notes);
    return itemId;
  }

  Future<void> updateItem(String id, Map<String, dynamic> changes) async {
    await _client.rpc(
      'inventory_update_item',
      params: {
        'p_item_id': id,
        'p_name': changes['name'],
        'p_description': changes['description'],
        'p_category': changes['category'],
        'p_min_quantity': changes['min_quantity'],
      },
    );
  }

  Future<void> deleteItem(String id) async {
    await _client.rpc('inventory_delete_item', params: {'p_item_id': id});
  }

  // Ops
  Future<void> receiveStock({
    required String itemId,
    required int quantity,
    String? notes,
  }) async {
    try {
      await _client.rpc(
        'inventory_receive_stock',
        params: {'p_item_id': itemId, 'p_quantity': quantity, 'p_notes': notes},
      );
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        // schema drift
        throw Exception(
          'Inventory schema mismatch detected. Please re-run database migrations to align the inventory table. (missing name-like column)',
        );
      }
      rethrow;
    }
  }

  Future<void> dispenseMedicines({
    required String itemId,
    required int quantity,
    required String patientName,
    String? notes,
  }) async {
    await _client.rpc(
      'inventory_dispense_medicines',
      params: {
        'p_item_id': itemId,
        'p_quantity': quantity,
        'p_patient_name': patientName,
        'p_notes': notes,
      },
    );
  }

  Future<void> adjustStock({
    required String itemId,
    required int delta,
    String? notes,
  }) async {
    await _client.rpc(
      'inventory_adjust_stock',
      params: {'p_item_id': itemId, 'p_delta': delta, 'p_notes': notes},
    );
  }

  Future<List<InventoryTxn>> listTransactions({
    DateTime? from,
    DateTime? to,
    String? type, // receive|dispense|adjust
    String? itemId,
  }) async {
    var query = _client.from('inventory_transactions').select();
    if (from != null) query = query.gte('created_at', from.toIso8601String());
    if (to != null) query = query.lte('created_at', to.toIso8601String());
    if (type != null && type.isNotEmpty) query = query.eq('type', type);
    if (itemId != null && itemId.isNotEmpty) {
      query = query.eq('item_id', itemId);
    }
    final res = await query.order('created_at', ascending: false);
    final rows = _rowsFrom(res);
    return rows.map(InventoryTxn.fromJson).toList();
  }

  Future<List<InventoryItem>> listInventory() async {
    final res = await _client.from('inventory').select();
    final rows = _rowsFrom(res);
    return rows.map(InventoryItem.fromJson).toList();
  }

  /// Upload image and set URL via RPC
  Future<String> uploadAndSetItemImage({
    required String itemId,
    required XFile xfile,
  }) async {
    final extPart = xfile.name.contains('.')
        ? xfile.name.split('.').last
        : (xfile.path.split('.').last);
    final ext = (extPart.isEmpty ? 'jpg' : extPart).toLowerCase();
    final fileName = '${itemId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'inventory/$itemId/$fileName';

    final bytes = await xfile.readAsBytes();
    await _client.storage
        .from('images')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final publicUrl = _client.storage.from('images').getPublicUrl(storagePath);
    await _client.rpc(
      'inventory_set_item_image',
      params: {'p_item_id': itemId, 'p_image_url': publicUrl},
    );
    return publicUrl;
  }
}
