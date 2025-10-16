import 'package:flutter/material.dart';
import '../../../../models/inventory_item.dart';
import '../../../../services/inventory_service.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';
import '../../../../core/utils/nav.dart';
import 'package:image_picker/image_picker.dart';
import 'inventory_edit_page.dart';

class InventoryDetailPage extends StatelessWidget {
  final InventoryItem item;
  const InventoryDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    final isLow =
        item.minQuantity != null && item.quantity <= (item.minQuantity ?? 0);
    return AppScaffold(
      title: item.name,
      role: role,
      currentLabel: 'Inventory',
      floatingActionButton: _ImageFab(item: item),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _HeaderFallback(isLow: isLow),
                    )
                  else
                    _HeaderFallback(isLow: isLow),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
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
                            item.name,
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
                        _QtyPill(quantity: item.quantity, isLow: isLow),
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
                  if (item.category != null)
                    Row(
                      children: [
                        const Icon(Icons.category, size: 18),
                        const SizedBox(width: 6),
                        Text(item.category!),
                      ],
                    ),
                  if (item.category != null) const SizedBox(height: 12),
                  if ((item.description ?? '').trim().isNotEmpty)
                    Text(
                      item.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    Text(
                      'No description provided.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(
                        label: 'Min Qty',
                        value: item.minQuantity?.toString() ?? '-',
                      ),
                      _InfoChip(
                        label: 'Created',
                        value: item.createdAt != null
                            ? item.createdAt!.toLocal().toString().substring(
                                0,
                                16,
                              )
                            : '-',
                      ),
                      _InfoChip(
                        label: 'Updated',
                        value: item.updatedAt != null
                            ? item.updatedAt!.toLocal().toString().substring(
                                0,
                                16,
                              )
                            : '-',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () async {
                        final updated = await Nav.pushWithRole<InventoryItem?>(
                          context,
                          InventoryEditPage(item: item),
                        );
                        if (updated != null && context.mounted) {
                          Navigator.of(context).pop(updated);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete item?'),
                            content: const Text(
                              'This will remove the inventory item.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await InventoryService.instance.deleteItem(item.id);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
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
}

class _QtyPill extends StatelessWidget {
  final int quantity;
  final bool isLow;
  const _QtyPill({required this.quantity, required this.isLow});

  @override
  Widget build(BuildContext context) {
    final bg = isLow
        ? Colors.orange.withValues(alpha: 0.2)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
    final fg = isLow ? Colors.orange : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Qty: $quantity',
        style: TextStyle(color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HeaderFallback extends StatelessWidget {
  final bool isLow;
  const _HeaderFallback({required this.isLow});

  @override
  Widget build(BuildContext context) {
    final bg = isLow
        ? Colors.orange.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final fg = isLow ? Colors.orange : Theme.of(context).colorScheme.primary;
    return Container(
      color: bg,
      child: Center(child: Icon(Icons.inventory_2, size: 72, color: fg)),
    );
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

class _ImageFab extends StatefulWidget {
  final InventoryItem item;
  const _ImageFab({required this.item});

  @override
  State<_ImageFab> createState() => _ImageFabState();
}

class _ImageFabState extends State<_ImageFab> {
  bool _busy = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, maxWidth: 1600);
      if (xfile == null) return;
      await InventoryService.instance.uploadAndSetItemImage(
        itemId: widget.item.id,
        xfile: xfile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image updated')));
      // optional refresh via pop
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return FloatingActionButton(
        onPressed: null,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Add/Change picture',
      onSelected: (v) async {
        if (v == 'camera') {
          await _pickAndUpload(ImageSource.camera);
        } else if (v == 'gallery') {
          await _pickAndUpload(ImageSource.gallery);
        }
      },
      itemBuilder: (ctx) => const [
        PopupMenuItem(
          value: 'camera',
          child: ListTile(
            leading: Icon(Icons.photo_camera),
            title: Text('Take photo'),
          ),
        ),
        PopupMenuItem(
          value: 'gallery',
          child: ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose from gallery'),
          ),
        ),
      ],
      child: FloatingActionButton(
        onPressed: null,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
