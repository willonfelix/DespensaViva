import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../environment/environment_controller.dart';
import '../environment/environment_detail_screen.dart';
import '../environment/environment_list_screen.dart';
import '../pantry/pantry_screen.dart';
import '../shopping/shopping_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(environmentWatcherProvider);
    final authState = ref.watch(authControllerProvider);
    final envState = ref.watch(environmentControllerProvider);

    if (!authState.isAuthenticated) {
      return const SizedBox.shrink();
    }

    // Carrega ambientes na primeira entrada
    if (envState.environments.isEmpty && !envState.loading) {
      Future.microtask(
          () => ref.read(environmentControllerProvider.notifier).load());
    }

    // Sem ambiente: tela de lista/criação
    if (envState.environments.isEmpty) {
      return const EnvironmentListScreen();
    }

    // Sem ambiente ativo: volta para a lista
    if (!envState.hasActiveEnvironment) {
      return const EnvironmentListScreen();
    }

    final activeEnv = envState.activeEnvironment!;

    return Scaffold(
      appBar: AppBar(
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: activeEnv.id,
            isDense: true,
            items: envState.environments
                .map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(
                        e.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ))
                .toList(),
            onChanged: (id) {
              if (id != null) {
                ref.read(environmentControllerProvider.notifier).selectEnvironment(id);
              }
            },
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Membros',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EnvironmentDetailScreen(environmentId: activeEnv.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          PantryScreen(),
          ShoppingListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EnvironmentListScreen()),
            );
            return;
          }
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.kitchen_outlined),
            selectedIcon: Icon(Icons.kitchen),
            label: 'Dispensa',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Compras',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_outlined),
            selectedIcon: Icon(Icons.home_work),
            label: 'Dispensas',
          ),
        ],
      ),
    );
  }
}
