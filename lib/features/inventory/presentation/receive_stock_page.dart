import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../../services/inventory_service.dart';
import '../../../../models/inventory_item.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';
import '../../../../core/utils/nav.dart';

class ReceiveStockPage extends StatefulWidget {
  const ReceiveStockPage({super.key});
  @override
  State<ReceiveStockPage> createState() => _ReceiveStockPageState();
}

class _ReceiveStockPageState extends State<ReceiveStockPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  InventoryItem? _selected;
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  // new item fields
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  XFile? _pickedImage;
  bool _busy = false;
  List<InventoryItem> _items = const [];
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final items = await InventoryService.instance.listInventory();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final qty = int.parse(_qtyCtrl.text.trim());
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();
      if (_tab.index == 0) {
        // existing item
        if (_selected == null) {
          return;
        }
        if (_pickedImage != null) {
          try {
            await InventoryService.instance.uploadAndSetItemImage(
              itemId: _selected!.id,
              xfile: _pickedImage!,
            );
          } catch (_) {}
        }
        await InventoryService.instance.receiveStock(
          itemId: _selected!.id,
          quantity: qty,
          notes: notes,
        );
      } else {
        // new: create + (image) + receive
        final minQ = _minCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(_minCtrl.text.trim());
        await InventoryService.instance.createItemAndReceive(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          category: _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim(),
          minQuantity: minQ,
          quantity: qty,
          notes: notes,
          image: _pickedImage,
        );
        // refresh list
        _load();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stock received')));
      await Nav.pushReplacementWithRole(context, const ReceiveStockPage());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    return AppScaffold(
      title: 'Receive Stock',
      role: role,
      currentLabel: 'Receive Stock',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Text(
              'Add incoming stock',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Select an existing item or create a new one, optionally add a photo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tab,
                      labelColor: Theme.of(context).colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Existing Item'),
                        Tab(text: 'New Item'),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            // existing
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Row(
                                  children: [
                                    _ImagePreview(
                                      file: _pickedImage,
                                      onClear: () =>
                                          setState(() => _pickedImage = null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final x = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.camera,
                                                    maxWidth: 2048,
                                                    imageQuality: 85,
                                                  );
                                              if (x != null) {
                                                setState(
                                                  () => _pickedImage = x,
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.photo_camera,
                                            ),
                                            label: const Text('Add photo'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final x = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                    maxWidth: 2048,
                                                    imageQuality: 85,
                                                  );
                                              if (x != null) {
                                                setState(
                                                  () => _pickedImage = x,
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.photo_library,
                                            ),
                                            label: const Text(
                                              'Choose from gallery',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<InventoryItem>(
                                  initialValue: _selected,
                                  items: _items
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selected = v),
                                  decoration: const InputDecoration(
                                    labelText: 'Item',
                                  ),
                                  validator: (v) =>
                                      v == null ? 'Select item' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _qtyCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      (int.tryParse(v ?? '') ?? 0) <= 0
                                      ? 'Enter > 0'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes (optional)',
                                  ),
                                ),
                              ],
                            ),
                            // new
                            ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Row(
                                  children: [
                                    _ImagePreview(
                                      file: _pickedImage,
                                      onClear: () =>
                                          setState(() => _pickedImage = null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final x = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.camera,
                                                    maxWidth: 2048,
                                                    imageQuality: 85,
                                                  );
                                              if (x != null) {
                                                setState(
                                                  () => _pickedImage = x,
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.photo_camera,
                                            ),
                                            label: const Text('Camera'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              final x = await ImagePicker()
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                    maxWidth: 2048,
                                                    imageQuality: 85,
                                                  );
                                              if (x != null) {
                                                setState(
                                                  () => _pickedImage = x,
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.photo_library,
                                            ),
                                            label: const Text('Gallery'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Item name',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Enter a name'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _descCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Description (optional)',
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _catCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Category (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _minCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Min quantity (optional)',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _qtyCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Initial quantity to receive',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      (int.tryParse(v ?? '') ?? 0) <= 0
                                      ? 'Enter > 0'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _notesCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes (optional)',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.download_done),
                      label: const Text('Receive Stock'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile? file;
  final VoidCallback onClear;
  const _ImagePreview({required this.file, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final has = file != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 84,
        height: 84,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        child: has
            ? Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List>(
                    future: file!.readAsBytes(),
                    builder: (context, snap) {
                      if (snap.hasData) {
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      }
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: InkWell(
                      onTap: onClear,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const Icon(Icons.photo, size: 28),
      ),
    );
  }
}
