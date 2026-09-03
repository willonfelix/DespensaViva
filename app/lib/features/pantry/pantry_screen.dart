import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pantry_item.dart';
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
            child: _buildList(state.loading && items.isEmpty, filtered, items.isEmpty),
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

  Widget _buildList(bool loading, List<PantryItem> filtered, bool empty) {
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
      itemBuilder: (context, index) => _PantryCard(item: filtered[index]),
    );
  }
}

class _PantryCard extends ConsumerWidget {
  final PantryItem item;

  const _PantryCard({required this.item});

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
          ],
        ),
      ),
    );
  }
}