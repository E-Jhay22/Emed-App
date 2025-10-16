import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/inventory_service.dart';
import '../../../../models/inventory_txn.dart';
import '../../../../models/inventory_item.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';

class InventoryReportsPage extends StatefulWidget {
  final String? initialItemId;
  final String? initialType; // receive|dispense|adjust
  const InventoryReportsPage({super.key, this.initialItemId, this.initialType});
  @override
  State<InventoryReportsPage> createState() => _InventoryReportsPageState();
}

class _InventoryReportsPageState extends State<InventoryReportsPage> {
  DateTime? _from;
  DateTime? _to;
  String? _type; // receive|dispense|adjust
  InventoryItem? _item;
  bool _loading = false;
  List<InventoryTxn> _txns = const [];
  List<InventoryItem> _items = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _loadItems();
    _refresh();
  }

  Future<void> _loadItems() async {
    final items = await InventoryService.instance.listInventory();
    if (!mounted) return;
    setState(() {
      _items = items;
      if (widget.initialItemId != null) {
        final idx = items.indexWhere((e) => e.id == widget.initialItemId);
        if (idx != -1) _item = items[idx];
      }
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final txns = await InventoryService.instance.listTransactions(
        from: _from,
        to: _to,
        type: _type,
        itemId: _item?.id,
      );
      if (!mounted) return;
      setState(() => _txns = txns);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refresh();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final init = isFrom ? (_from ?? now) : (_to ?? now);
    final date = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (date != null) {
      setState(() {
        if (isFrom) {
          _from = DateTime(date.year, date.month, date.day);
        } else {
          _to = DateTime(date.year, date.month, date.day, 23, 59, 59);
        }
      });
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    return AppScaffold(
      title: 'Inventory Reports',
      role: role,
      currentLabel: 'Inventory Reports',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                if (isNarrow) {
                  // stack on small
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: const Text('All'),
                          ),
                          const DropdownMenuItem<String?>(
                            value: 'receive',
                            child: Text('Receive'),
                          ),
                          const DropdownMenuItem<String?>(
                            value: 'dispense',
                            child: Text('Dispense'),
                          ),
                          const DropdownMenuItem<String?>(
                            value: 'adjust',
                            child: Text('Adjust'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _type = v);
                          _scheduleRefresh();
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<InventoryItem?>(
                        initialValue: _item,
                        decoration: const InputDecoration(labelText: 'Item'),
                        items: [
                          DropdownMenuItem<InventoryItem?>(
                            value: null,
                            child: const Text('All items'),
                          ),
                          ..._items.map(
                            (e) => DropdownMenuItem<InventoryItem?>(
                              value: e,
                              child: Text(e.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _item = v);
                          _scheduleRefresh();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _from == null
                                  ? 'From'
                                  : _from!.toIso8601String().substring(0, 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _to == null
                                  ? 'To'
                                  : _to!.toIso8601String().substring(0, 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                // wide: single row
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _type,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: const Text('All'),
                          ),
                          const DropdownMenuItem<String?>(
                            value: 'receive',
                            child: Text('Receive'),
                          ),
                          const DropdownMenuItem<String?>(
                            value: 'dispense',
                            child: Text('Dispense'),
                          ),
                          const DropdownMenuItem<String?>(
                            value: 'adjust',
                            child: Text('Adjust'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _type = v);
                          _scheduleRefresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<InventoryItem?>(
                        initialValue: _item,
                        decoration: const InputDecoration(labelText: 'Item'),
                        items: [
                          DropdownMenuItem<InventoryItem?>(
                            value: null,
                            child: const Text('All items'),
                          ),
                          ..._items.map(
                            (e) => DropdownMenuItem<InventoryItem?>(
                              value: e,
                              child: Text(e.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _item = v);
                          _scheduleRefresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints.tightFor(width: 200),
                      child: Column(
                        children: [
                          TextButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _from == null
                                  ? 'From'
                                  : _from!.toIso8601String().substring(0, 10),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _to == null
                                  ? 'To'
                                  : _to!.toIso8601String().substring(0, 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _txns.isEmpty
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      children: const [Center(child: Text('No transactions'))],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: _txns.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final t = _txns[i];
                        final when = t.createdAt.toLocal().toString();
                        return ListTile(
                          title: Text(
                            '${t.type.toUpperCase()} • ${t.itemName}',
                          ),
                          subtitle: Text(
                            'Delta: ${t.delta} • New Qty: ${t.newQuantity}\nBy: ${t.actorName ?? t.actorId}${t.patientName != null ? ' • Patient: ${t.patientName}' : ''}\n$when',
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
