import 'package:flutter/material.dart';
import '../../../../services/inventory_service.dart';
import '../../../../models/inventory_item.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/role_scope.dart';
import '../../../../core/utils/nav.dart';
import 'inventory_detail_page.dart';

class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key});

  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  late Stream<List<InventoryItem>> _stream;
  String _search = '';
  String? _category;
  bool _lowStockOnly = false;
  String _sort = 'name'; // name|qty|low

  @override
  void initState() {
    super.initState();
    _stream = InventoryService.instance.streamInventory();
  }

  Future<void> _refresh() async {
    setState(() {
      _stream = InventoryService.instance.streamInventory();
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleScope.of(context);
    return AppScaffold(
      title: 'Inventory',
      role: role,
      currentLabel: 'Inventory',
      // creation disabled here
      body: StreamBuilder<List<InventoryItem>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var items = snapshot.data ?? [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 64),
                children: const [Center(child: Text('No inventory items'))],
              ),
            );
          }
          final categories = <String>{}
            ..addAll(items.map((e) => e.category).whereType<String>());

          // filter
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            items = items.where((e) {
              final inName = e.name.toLowerCase().contains(q);
              final inDesc = (e.description ?? '').toLowerCase().contains(q);
              final inCat = (e.category ?? '').toLowerCase().contains(q);
              return inName || inDesc || inCat;
            }).toList();
          }
          if (_category != null && _category!.isNotEmpty) {
            items = items.where((e) => e.category == _category).toList();
          }
          if (_lowStockOnly) {
            items = items
                .where(
                  (e) => e.minQuantity != null && e.quantity <= e.minQuantity!,
                )
                .toList();
          }
          // sort
          items.sort((a, b) {
            switch (_sort) {
              case 'qty':
                return b.quantity.compareTo(a.quantity);
              case 'low':
                final lowA =
                    (a.minQuantity != null && a.quantity <= a.minQuantity!)
                    ? 1
                    : 0;
                final lowB =
                    (b.minQuantity != null && b.quantity <= b.minQuantity!)
                    ? 1
                    : 0;
                final cmp = lowB.compareTo(lowA);
                if (cmp != 0) return cmp;
                return a.name.compareTo(b.name);
              case 'name':
              default:
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search name, description, category',
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              DropdownButton<String>(
                                hint: const Text('Category'),
                                value: _category?.isEmpty == true
                                    ? null
                                    : _category,
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('All'),
                                  ),
                                  ...categories.map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () =>
                                      _category = (v ?? '').isEmpty ? null : v,
                                ),
                              ),
                              DropdownButton<String>(
                                value: _sort,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'name',
                                    child: Text('Name'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'qty',
                                    child: Text('Qty'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'low',
                                    child: Text('Low first'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _sort = v ?? 'name'),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Low only'),
                                  Switch(
                                    value: _lowStockOnly,
                                    onChanged: (v) =>
                                        setState(() => _lowStockOnly = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    // wide
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search name, description, category',
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 140),
                          child: DropdownButton<String>(
                            hint: const Text('Category'),
                            value: _category?.isEmpty == true
                                ? null
                                : _category,
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('All'),
                              ),
                              ...categories.map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(
                              () => _category = (v ?? '').isEmpty ? null : v,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 120),
                          child: DropdownButton<String>(
                            value: _sort,
                            items: const [
                              DropdownMenuItem(
                                value: 'name',
                                child: Text('Name'),
                              ),
                              DropdownMenuItem(
                                value: 'qty',
                                child: Text('Qty'),
                              ),
                              DropdownMenuItem(
                                value: 'low',
                                child: Text('Low first'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _sort = v ?? 'name'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Text('Low only'),
                            Switch(
                              value: _lowStockOnly,
                              onChanged: (v) =>
                                  setState(() => _lowStockOnly = v),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final it = items[index];
                      final isLow =
                          it.minQuantity != null &&
                          it.quantity <= it.minQuantity!;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Nav.pushWithRole(
                          context,
                          InventoryDetailPage(item: it),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    it.imageUrl != null &&
                                        it.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        it.imageUrl!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _FallbackThumb(isLow: isLow),
                                      )
                                    : _FallbackThumb(isLow: isLow),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      it.category ?? 'Uncategorized',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLow
                                          ? Colors.orange.withValues(
                                              alpha: 0.15,
                                            )
                                          : Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Qty: ${it.quantity}',
                                      style: TextStyle(
                                        color: isLow
                                            ? Colors.orange
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (it.minQuantity != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Min: ${it.minQuantity}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  final bool isLow;
  const _FallbackThumb({required this.isLow});

  @override
  Widget build(BuildContext context) {
    final bg = isLow
        ? Colors.orange.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final fg = isLow ? Colors.orange : Theme.of(context).colorScheme.primary;
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.inventory_2, color: fg),
    );
  }
}
