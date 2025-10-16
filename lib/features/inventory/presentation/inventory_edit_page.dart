import 'package:flutter/material.dart';
import '../../../../models/inventory_item.dart';
import '../../../../services/inventory_service.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';

class InventoryEditPage extends StatefulWidget {
  final InventoryItem? item;
  const InventoryEditPage({super.key, this.item});

  @override
  State<InventoryEditPage> createState() => _InventoryEditPageState();
}

class _InventoryEditPageState extends State<InventoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _categoryController;
  late TextEditingController _quantityController;
  late TextEditingController _minController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _nameController = TextEditingController(text: it?.name ?? '');
    _descController = TextEditingController(text: it?.description ?? '');
    _categoryController = TextEditingController(text: it?.category ?? '');
    _quantityController = TextEditingController(
      text: it?.quantity.toString() ?? '0',
    );
    _minController = TextEditingController(
      text: it?.minQuantity?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _minController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      final cat = _categoryController.text.trim();
      final minQ = int.tryParse(_minController.text.trim());

      if (widget.item == null) {
        // new item: allow initial qty
        final qty = int.tryParse(_quantityController.text.trim()) ?? 0;
        final newItem = InventoryItem(
          id: 'local-temp',
          name: name,
          description: desc.isEmpty ? null : desc,
          category: cat.isEmpty ? null : cat,
          quantity: qty,
          minQuantity: minQ,
        );
        await InventoryService.instance.addItem(newItem);
        if (!mounted) return;
        Navigator.of(context).pop(newItem);
      } else {
        // editing: don't change qty
        final changes = <String, dynamic>{
          'name': name,
          'description': desc.isEmpty ? null : desc,
          'category': cat.isEmpty ? null : cat,
          'min_quantity': minQ,
        };
        await InventoryService.instance.updateItem(widget.item!.id, changes);
        final updated = InventoryItem(
          id: widget.item!.id,
          name: name,
          description: desc.isEmpty ? null : desc,
          category: cat.isEmpty ? null : cat,
          // keep qty
          quantity: widget.item!.quantity,
          minQuantity: minQ,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    final role = RoleScope.of(context);
    return AppScaffold(
      title: isEdit ? 'Edit Item' : 'Create Item',
      role: role,
      currentLabel: 'Inventory',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (isEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stock quantity cannot be edited here. Use Receive, Dispense, or Adjust to change stock.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!isEdit)
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Quantity',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v ?? '') == null
                      ? 'Must be an integer'
                      : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minController,
                decoration: const InputDecoration(
                  labelText: 'Min Quantity',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _save,
                      child: Text(isEdit ? 'Save' : 'Create'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
