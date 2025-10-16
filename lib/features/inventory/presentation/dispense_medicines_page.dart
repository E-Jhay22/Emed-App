import 'package:flutter/material.dart';
import '../../../../services/inventory_service.dart';
import '../../../../models/inventory_item.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';

class DispenseMedicinesPage extends StatefulWidget {
  const DispenseMedicinesPage({super.key});
  @override
  State<DispenseMedicinesPage> createState() => _DispenseMedicinesPageState();
}

class _DispenseMedicinesPageState extends State<DispenseMedicinesPage> {
  final _formKey = GlobalKey<FormState>();
  final _patientCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _busy = false;
  List<InventoryItem> _items = const [];
  String _search = '';
  final Map<String, int> _selectedQty = {}; // itemId -> qty

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await InventoryService.instance.listInventory();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _submit() async {
    if (_selectedQty.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    final patient = _patientCtrl.text.trim();
    if (patient.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient name is required')),
        );
      }
      return;
    }
    final notes = _notesCtrl.text.trim().isEmpty
        ? null
        : _notesCtrl.text.trim();
    setState(() => _busy = true);
    try {
      for (final entry in _selectedQty.entries) {
        final itemId = entry.key;
        final qty = entry.value;
        if (qty <= 0) continue;
        await InventoryService.instance.dispenseMedicines(
          itemId: itemId,
          quantity: qty,
          patientName: patient,
          notes: notes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dispensed')));
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
    if (_selectedQty.isEmpty) return;
    final idToItem = {for (final it in _items) it.id: it};
    final lines = _selectedQty.entries
        .where((e) => e.value > 0 && idToItem.containsKey(e.key))
        .map((e) => {'item': idToItem[e.key]!, 'qty': e.value})
        .toList();
    final totalItems = lines.length;
    final totalQty = lines.fold<int>(0, (sum, l) => sum + (l['qty'] as int));

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm dispense'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...lines.map((l) {
                  final it = l['item'] as InventoryItem;
                  final q = l['qty'] as int;
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
                          'x$q',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Text('Total items: $totalItems'),
                Text('Total quantity: $totalQty'),
                if (_patientCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Patient: ${_patientCtrl.text.trim()}'),
                ],
                if (_notesCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
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
                await _submit();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditQtyDialog(InventoryItem it) async {
    final current = _selectedQty[it.id] ?? 1;
    final ctrl = TextEditingController(text: current.toString());
    final newVal = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Set quantity for ${it.name}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              helperText: 'Enter 0 to remove',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(ctrl.text.trim());
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
      final clamped = newVal.clamp(0, it.quantity);
      if (clamped <= 0) {
        _selectedQty.remove(it.id);
      } else {
        _selectedQty[it.id] = clamped;
      }
    });
  }

  void _toggleItem(InventoryItem it) {
    setState(() {
      if (_selectedQty.containsKey(it.id)) {
        _selectedQty.remove(it.id);
      } else {
        if (it.quantity > 0) _selectedQty[it.id] = 1;
      }
    });
  }

  void _inc(String id) {
    final it = _items.firstWhere((e) => e.id == id);
    setState(() {
      final cur = _selectedQty[id] ?? 0;
      final next = (cur + 1).clamp(0, it.quantity);
      _selectedQty[id] = next;
    });
  }

  void _dec(String id) {
    setState(() {
      final cur = _selectedQty[id] ?? 0;
      final next = (cur - 1).clamp(0, 1 << 30);
      if (next <= 0) {
        _selectedQty.remove(id);
      } else {
        _selectedQty[id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    return AppScaffold(
      title: 'Dispense Medicines',
      role: role,
      currentLabel: 'Dispense Medicines',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select items to dispense',
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
                        final selected = _selectedQty.containsKey(it.id);
                        final isLow =
                            it.minQuantity != null &&
                            it.quantity <= it.minQuantity!;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _toggleItem(it),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                // subtle ambient
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                                // gentle drop
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                width: selected ? 2 : 1,
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
                                  child: selected
                                      ? _QtyStepper(
                                          value: _selectedQty[it.id]!,
                                          onDec: () => _dec(it.id),
                                          onInc: () => _inc(it.id),
                                          onEdit: () => _showEditQtyDialog(it),
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: () => _toggleItem(it),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('Add'),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _patientCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name',
                        hintText: 'Required',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Patient name is required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _confirmAndSubmit,
                        icon: const Icon(Icons.local_hospital),
                        label: const Text('Dispense Selected'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int value;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback? onEdit;
  const _QtyStepper({
    required this.value,
    required this.onInc,
    required this.onDec,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onDec,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          onPressed: onInc,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
