import 'package:flutter/material.dart';
import '../../../../services/inventory_service.dart';
import '../../../../models/inventory_item.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';

class AdjustStockPage extends StatefulWidget {
  const AdjustStockPage({super.key});
  @override
  State<AdjustStockPage> createState() => _AdjustStockPageState();
}

class _AdjustStockPageState extends State<AdjustStockPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  bool _busy = false;
  String _search = '';
  List<InventoryItem> _items = const [];
  final Map<String, int> _deltas = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await InventoryService.instance.listInventory();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _submitBatch() async {
    final entries = _deltas.entries.where((e) => e.value != 0).toList();
    if (entries.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final e in entries) {
        await InventoryService.instance.adjustStock(
          itemId: e.key,
          delta: e.value,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock adjusted')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndSubmit() async {
    final entries = _deltas.entries.where((e) => e.value != 0).toList();
    if (entries.isEmpty) return;
    final idToItem = {for (final it in _items) it.id: it};
    final lines = entries
        .where((e) => idToItem.containsKey(e.key))
        .map(
          (e) => {
            'item': idToItem[e.key]!,
            'delta': e.value,
            'newQty': (idToItem[e.key]!.quantity + e.value).clamp(0, 1 << 30),
          },
        )
        .toList();
    final totalItems = lines.length;
    final netDelta = lines.fold<int>(0, (sum, l) => sum + (l['delta'] as int));

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm adjustments'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...lines.map((l) {
                  final it = l['item'] as InventoryItem;
                  final d = l['delta'] as int;
                  final newQ = l['newQty'] as int;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$d -> $newQ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Text('Total items: $totalItems'),
                Text('Net change: ${netDelta > 0 ? '+' : ''}$netDelta'),
                if (_notesCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notes: ${_notesCtrl.text.trim()}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _submitBatch();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _inc(String id) {
    setState(() {
      _deltas[id] = (_deltas[id] ?? 0) + 1;
    });
  }

  void _dec(String id) {
    setState(() {
      _deltas[id] = (_deltas[id] ?? 0) - 1;
      if (_deltas[id] == 0) _deltas.remove(id);
    });
  }

  Future<void> _showEditDeltaDialog(InventoryItem it) async {
    final current = _deltas[it.id] ?? 0;
    final ctrl = TextEditingController(text: current.toString());
    final newVal = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Set change for ${it.name}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: false,
            ),
            decoration: const InputDecoration(
              labelText: 'Change (e.g. +5 or -3)',
              helperText: '0 clears the change',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final txt = ctrl.text.trim();
                final parsed = int.tryParse(txt);
                if (parsed == null) {
                  Navigator.of(ctx).pop();
                  return;
                }
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (newVal == null) return;
    setState(() {
      if (newVal == 0) {
        _deltas.remove(it.id);
      } else {
        _deltas[it.id] = newVal;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    return AppScaffold(
      title: 'Adjust Stock',
      role: role,
      currentLabel: 'Adjust Stock',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust stock for items',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name or category',
                ),
                onChanged: (v) => setState(() => _search = v.trim()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final colWidth = 160.0;
                    final crossAxisCount = (constraints.maxWidth / colWidth)
                        .floor()
                        .clamp(2, 6);
                    var items = _items;
                    if (_search.isNotEmpty) {
                      final q = _search.toLowerCase();
                      items = items.where((e) {
                        final inName = e.name.toLowerCase().contains(q);
                        final inCat = (e.category ?? '').toLowerCase().contains(
                          q,
                        );
                        return inName || inCat;
                      }).toList();
                    }
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final it = items[index];
                        final isLow =
                            it.minQuantity != null &&
                            it.quantity <= it.minQuantity!;
                        final delta = _deltas[it.id] ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: delta != 0
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              width: delta != 0 ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    (it.imageUrl != null &&
                                        it.imageUrl!.isNotEmpty)
                                    ? Image.network(
                                        it.imageUrl!,
                                        width: double.infinity,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        height: 72,
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isLow
                                              ? Colors.orange.withValues(
                                                  alpha: 0.12,
                                                )
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2,
                                          color: isLow
                                              ? Colors.orange
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                it.name,
                                style: Theme.of(context).textTheme.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLow
                                          ? Colors.orange.withValues(
                                              alpha: 0.15,
                                            )
                                          : Colors.green.withValues(
                                              alpha: 0.15,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Qty: ${it.quantity}',
                                      style: TextStyle(
                                        color: isLow
                                            ? Colors.orange
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (it.minQuantity != null)
                                    Text(
                                      'Min: ${it.minQuantity}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 40,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: () => _dec(it.id),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showEditDeltaDialog(it),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.outlineVariant,
                                          ),
                                        ),
                                        child: Text(
                                          delta.toString(),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _inc(it.id),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 16),
              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _confirmAndSubmit,
                        icon: const Icon(Icons.inventory_outlined),
                        label: const Text('Apply Adjustments'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
