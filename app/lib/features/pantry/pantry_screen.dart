import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pantry_item.dart';
import '../../models/pending_change.dart';
import '../pantry/pantry_controller.dart';
import '../products/add_product_screen.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(pantryControllerProvider.notifier).load();
    });
  }

  Future<void> _openAddProduct() async {
    final nav = Navigator.of(context);
    final result = await nav.push<bool>(
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item adicionado à dispensa!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pantryControllerProvider);
    final items = state.items;
    final filters = _brandFilters(items);

    final filtered = items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    final pendingIds = state.pending.map((p) => p.pantryItemId).toSet();
    final pendingByItem = {for (final p in state.pending) p.pantryItemId: p};
    final hasPending = state.pendingCount > 0;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Pesquisar item na dispensa...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 10),
                if (hasPending) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pending_actions,
                            size: 18, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${state.pendingCount} alteração(ões) pendente(s). Confirme em Perfil p/ aplicar.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: _selectedCategory == null,
                        onSelected: (_) => setState(() => _selectedCategory = null),
                      ),
                      ...filters.map((category) {
                        final isSelected = _selectedCategory == category;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = isSelected ? null : category),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildList(state.loading && items.isEmpty, filtered, items.isEmpty, pendingByItem),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
    );
  }

  List<String> _brandFilters(List<PantryItem> items) {
    final set = <String>{};
    for (final item in items) {
      if (item.category.isNotEmpty) set.add(item.category);
    }
    return set.toList();
  }

  Widget _buildList(
    bool loading,
    List<PantryItem> filtered,
    bool empty,
    Map<int, PendingChange> pendingByItem,
  ) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (empty) {
      return const Center(child: Text('Sua dispensa está vazia.\nToque em Adicionar para começar.'));
    }
    if (filtered.isEmpty) {
      return const Center(child: Text('Nenhum item encontrado.'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _PantryCard(
          item: item,
          pending: pendingByItem[item.id],
        );
      },
    );
  }
}

class _PantryCard extends ConsumerWidget {
  final PantryItem item;
  final PendingChange? pending;

  const _PantryCard({required this.item, this.pending});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${item.name}"?'),
        content: const Text('Este item será removido da dispensa. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(pantryControllerProvider.notifier).remove(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Item removido da dispensa.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowStock = item.isLowStock;
    final expired = item.isExpired;
    final nearExpiration = !expired && item.isNearExpiration;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 64,
              decoration: BoxDecoration(
                color: expired
                    ? Colors.red.shade700
                    : isLowStock
                        ? Colors.orange.shade700
                        : nearExpiration
                            ? Colors.amber.shade600
                            : Colors.green.shade600,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [if (item.category.isNotEmpty) item.category,
                     if (expired) 'Vencido',
                     if (nearExpiration) 'Vence em breve']
                        .join(' • '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (pending != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Pendente: ${PantryController.format(pending!.newQuantity, pending!.unitOfMeasure)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        PantryController.format(item.quantity, item.unitOfMeasure),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isLowStock ? Colors.orange.shade800 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'mín ${PantryController.format(item.minQuantity, item.unitOfMeasure)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red.shade400,
                  onPressed: () =>
                      ref.read(pantryControllerProvider.notifier).decrement(item),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green.shade600,
                  onPressed: () =>
                      ref.read(pantryControllerProvider.notifier).increment(item),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}