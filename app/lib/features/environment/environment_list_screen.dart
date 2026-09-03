import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../pantry/pantry_controller.dart';
import '../shopping/shopping_controller.dart';
import 'environment_controller.dart';

class EnvironmentListScreen extends ConsumerStatefulWidget {
  const EnvironmentListScreen({super.key});

  @override
  ConsumerState<EnvironmentListScreen> createState() => _EnvironmentListScreenState();
}

class _EnvironmentListScreenState extends ConsumerState<EnvironmentListScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(environmentControllerProvider.notifier).load();
    });
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome da Dispensa.')),
      );
      return;
    }
    final ok = await ref.read(environmentControllerProvider.notifier).create(name);
    _nameController.clear();
    if (ok) {
      ref.read(pantryControllerProvider.notifier).load();
      ref.read(shoppingControllerProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentControllerProvider);
    final envs = state.environments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Dispensas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.environments.isEmpty && !state.loading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.kitchen_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'Você ainda não tem nenhuma Dispensa.\nCrie uma para começar a compartilhar itens.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (state.loading && envs.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: envs.length,
                itemBuilder: (context, index) {
                  final env = envs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.kitchen),
                      title: Text(env.name),
                      subtitle: Text('${env.memberCount} membro(s)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => ref
                          .read(environmentControllerProvider.notifier)
                          .selectEnvironment(env.id),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 8),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Nome da nova Dispensa',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
