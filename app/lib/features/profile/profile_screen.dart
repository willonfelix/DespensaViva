import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../pantry/pantry_controller.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _geminiKey = TextEditingController();
  bool _obscurePass = true;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(pantryControllerProvider.notifier).load();
      ref.read(profileControllerProvider.notifier).loadAudit();
    });
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _geminiKey.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 6) {
      _showMessage('A nova senha deve ter no mínimo 6 caracteres.', isError: true);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _showMessage('A confirmação não confere.', isError: true);
      return;
    }
    final ok = await ref.read(profileControllerProvider.notifier).updatePassword(
          _currentPassword.text,
          _newPassword.text,
        );
    if (ok) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    }
  }

  Future<void> _saveGeminiKey() async {
    final ok = await ref.read(profileControllerProvider.notifier).saveGeminiKey(
          _geminiKey.text,
        );
    if (ok) _geminiKey.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    ref.listen(profileControllerProvider, (prev, next) {
      if (next.success != null) _showMessage(next.success!);
      if (next.error != null) _showMessage(next.error!, isError: true);
      if (next.success != null || next.error != null) {
        Future.microtask(() => ref.read(profileControllerProvider.notifier).clearFeedback());
      }
    });

    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conta', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(user?.name ?? 'Sem nome'),
                      subtitle: Text(user?.email ?? ''),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildPendingCard(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('API Google (Gemini)', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Necessária para gerar sugestões inteligentes de consumo.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    if (user?.hasGeminiKey == true) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Text('Chave cadastrada', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _geminiKey,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        labelText: user?.hasGeminiKey == true
                            ? 'Nova chave (ou deixe vazio para manter)'
                            : 'Chave da API Gemini',
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: profileState.loading ? null : _saveGeminiKey,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Salvar chave'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (user?.hasGeminiKey == true)
                          OutlinedButton(
                            onPressed: profileState.loading
                                ? null
                                : () => ref.read(profileControllerProvider.notifier).saveGeminiKey(''),
                            child: const Text('Remover'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Trocar senha', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _passwordField(
                      controller: _currentPassword,
                      label: 'Senha atual',
                    ),
                    const SizedBox(height: 12),
                    _passwordField(
                      controller: _newPassword,
                      label: 'Nova senha',
                      obscure: _obscurePass,
                      onToggle: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmar nova senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: profileState.loading ? null : _changePassword,
                      icon: const Icon(Icons.password),
                      label: const Text('Alterar senha'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildAuditCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard() {
    final theme = Theme.of(context);
    final pantryState = ref.watch(pantryControllerProvider);
    final pending = pantryState.pending;
    final profileLoading = ref.watch(profileControllerProvider).loading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.amber.shade800, size: 22),
                const SizedBox(width: 8),
                Text('Alterações na dispensa', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Text(
                'Nenhuma alteração pendente.',
                style: TextStyle(color: Colors.grey),
              )
            else ...[
              ...pending.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.receipt_long),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${PantryController.format(p.currentQuantity, p.unitOfMeasure)} → '
                      '${PantryController.format(p.newQuantity, p.unitOfMeasure)}',
                      style: TextStyle(color: Colors.amber.shade900),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Cancelar',
                      onPressed: profileLoading
                          ? null
                          : () => ref.read(pantryControllerProvider.notifier).cancelPending(p.id),
                    ),
                  )),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: profileLoading
                    ? null
                    : () => ref.read(profileControllerProvider.notifier).confirmPending(),
                icon: const Icon(Icons.check_circle_outline),
                label: Text('Confirmar alterações (${pending.length})'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditCard(ThemeData theme) {
    final logs = ref.watch(profileControllerProvider).logs;
    final loadingAudit = ref.watch(profileControllerProvider).loadingAudit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text('Histórico de auditoria', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (loadingAudit)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (logs.isEmpty)
              const Text(
                'Nenhuma operação registrada.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...logs.take(50).map((log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(_auditIcon(log.action), color: _auditColor(log.action), size: 22),
                    title: Text(
                      '${log.itemName.isNotEmpty ? log.itemName : ''} ${log.title}'.trim(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(_formatDate(log.createdAt)),
                  )),
          ],
        ),
      ),
    );
  }

  IconData _auditIcon(String action) {
    switch (action) {
      case 'auth.login':
        return Icons.login;
      case 'pantry.quantity_change':
        return Icons.swap_horiz;
      case 'pantry.add':
        return Icons.add_circle_outline;
      case 'pantry.delete':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _auditColor(String action) {
    switch (action) {
      case 'auth.login':
        return Colors.blue;
      case 'pantry.quantity_change':
        return Colors.orange;
      case 'pantry.add':
        return Colors.green;
      case 'pantry.delete':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    bool? obscure,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure ?? true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(obscure! ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggle,
              )
            : null,
      ),
    );
  }
}
