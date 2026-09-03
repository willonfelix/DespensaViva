import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/shopping_list_item.dart';
import '../shopping/shopping_controller.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(shoppingControllerProvider.notifier).sync());
  }

  Future<void> _buySelected() async {
    final state = ref.read(shoppingControllerProvider);
    if (state.checkedCount == 0) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar compra?'),
        content: Text(
          'Adicionar ${state.checkedCount} item(ns) comprado(s) de volta à dispensa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      try {
        await ref.read(shoppingControllerProvider.notifier).buySelected();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itens comprados adicionados de volta à dispensa!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao finalizar a compra.'), backgroundColor: Colors.red),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shoppingControllerProvider);
    final items = state.items;
    final checkedCount = state.checkedCount;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(shoppingControllerProvider.notifier).sync(),
        child: state.loading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 64, color: Colors.green),
                            SizedBox(height: 16),
                            Text(
                              'Sua dispensa está abastecida!\nNenhum item abaixo do mínimo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ShoppingTile(item: item);
                    },
                  ),
      ),
      bottomNavigationBar: items.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: checkedCount > 0 ? _buySelected : null,
                  icon: const Icon(Icons.shopping_bag),
                  label: Text('Finalizar Compra ($checkedCount selecionados)'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  bool get loading => ref.read(shoppingControllerProvider).loading;
}

class _ShoppingTile extends ConsumerWidget {
  final ShoppingListItem item;

  const _ShoppingTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CheckboxListTile(
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          decoration: item.isChecked ? TextDecoration.lineThrough : null,
          color: item.isChecked ? Colors.grey : Colors.black87,
        ),
      ),
      subtitle: Text(
        [if (item.category.isNotEmpty) item.category,
         'Sugestão: ${item.suggestedQuantity.toStringAsFixed(1)} ${item.unitOfMeasure}']
            .join(' • '),
      ),
      secondary: CircleAvatar(
        backgroundColor: item.isChecked ? Colors.green.shade100 : Colors.orange.shade100,
        child: Icon(
          item.isChecked ? Icons.check : Icons.shopping_cart_outlined,
          color: item.isChecked ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
      value: item.isChecked,
      onChanged: (value) {
        if (value != null) {
          ref.read(shoppingControllerProvider.notifier).toggle(item);
        }
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}