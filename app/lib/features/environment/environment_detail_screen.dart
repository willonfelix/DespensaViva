import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/environment.dart';
import 'environment_controller.dart';

class EnvironmentDetailScreen extends ConsumerStatefulWidget {
  final String environmentId;

  const EnvironmentDetailScreen({super.key, required this.environmentId});

  @override
  ConsumerState<EnvironmentDetailScreen> createState() => _EnvironmentDetailScreenState();
}

class _EnvironmentDetailScreenState extends ConsumerState<EnvironmentDetailScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(environmentControllerProvider.notifier).loadDetail(widget.environmentId);
    });
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    final ok = await ref
        .read(environmentControllerProvider.notifier)
        .invite(widget.environmentId, email);
    _emailController.clear();
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membro adicionado!')),
      );
    } else {
      final error = ref.read(environmentControllerProvider).error;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Falha ao convidar.'), backgroundColor: Colors.red.shade700),
        );
      }
    }
    ref.read(environmentControllerProvider.notifier).loadDetail(widget.environmentId);
  }

  Future<void> _confirmRemove(EnvironmentMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover membro?'),
        content: Text('Deseja remover ${member.name ?? member.email} deste ambiente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(environmentControllerProvider.notifier)
          .removeMember(widget.environmentId, member.userId);
      ref.read(environmentControllerProvider.notifier).loadDetail(widget.environmentId);
    }
  }

  Future<void> _rename(Environment env) async {
    final controller = TextEditingController(text: env.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear Dispensa'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref.read(environmentControllerProvider.notifier).rename(widget.environmentId, newName);
      ref.read(environmentControllerProvider.notifier).loadDetail(widget.environmentId);
    }
  }

  Future<void> _delete(Environment env) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Dispensa?'),
        content: const Text('Todos os itens desta Dispensa serão excluídos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(environmentControllerProvider.notifier).remove(widget.environmentId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(environmentControllerProvider);
    final envs = state.environments;
    Environment? found;
    for (final e in envs) {
      if (e.id == widget.environmentId) {
        found = e;
        break;
      }
    }
    final env = found ?? state.activeEnvironment;
    if (env == null) {
      return const Scaffold(
        body: Center(child: Text('Ambiente não encontrado.')),
      );
    }
    final members = env.members;

    return Scaffold(
      appBar: AppBar(
        title: Text(env.name),
        centerTitle: true,
        actions: [
          if (env.isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Renomear',
              onPressed: () => _rename(env),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (env.isOwner) ...[
            const Text('Adicionar membro',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'E-mail do usuário',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _invite(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _invite,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Convidar'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
          ],
          const Text('Membros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...members.map((member) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text((member.name ?? member.email)
                        .substring(0, 1)
                        .toUpperCase()),
                  ),
                  title: Text(member.name ?? member.email),
                  subtitle: Text(member.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(member.isOwner ? 'Dono' : 'Membro'),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (env.isOwner && !member.isOwner)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'remove') {
                              _confirmRemove(member);
                            } else if (value == 'owner') {
                              ref
                                  .read(environmentControllerProvider.notifier)
                                  .changeRole(widget.environmentId, member.userId, 'owner');
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'owner',
                              child: Text('Tornar dono'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text('Remover'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              )),
          if (env.isOwner) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _delete(env),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir Dispensa'),
            ),
          ],
        ],
      ),
    );
  }
}
