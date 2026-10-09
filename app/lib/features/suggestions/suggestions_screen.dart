import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formatter.dart' show formatDate;
import '../auth/auth_controller.dart';
import '../environment/environment_controller.dart';
import '../profile/profile_screen.dart';
import 'suggestions_controller.dart';

String _formatGenTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${formatDate(dt)} $h:$m';
}

class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final env = ref.read(environmentControllerProvider).activeEnvironment;
    if (env != null && !_initialized) {
      _initialized = true;
      Future.microtask(
        () => ref.read(suggestionsControllerProvider.notifier).loadEnvironment(env.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final envState = ref.watch(environmentControllerProvider);
    final suggestionState = ref.watch(suggestionsControllerProvider);
    final env = envState.activeEnvironment;

    if (authState.user?.hasGeminiKey != true) {
      return _NoKeyMessage(
        onGoProfile: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      );
    }

    if (env == null) {
      return const Center(child: Text('Selecione uma dispensa.'));
    }

    final suggestions = suggestionState.suggestions;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(suggestionsControllerProvider.notifier).generate(env.id),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sugestões Inteligentes',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Gerar novas sugestões',
                onPressed: suggestionState.loading
                    ? null
                    : () => ref
                        .read(suggestionsControllerProvider.notifier)
                        .forceRefresh(env.id),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (suggestionState.generatedAt != null)
            Text(
              'Gerado em: ${_formatGenTime(suggestionState.generatedAt!)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          const SizedBox(height: 12),
          if (suggestionState.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (suggestionState.error != null)
            _MessageBox(
              icon: Icons.error_outline,
              message: suggestionState.error!,
              color: Colors.red.shade700,
            )
          else if (suggestions == null || suggestions.isEmpty)
            Column(
              children: [
                const SizedBox(height: 32),
                Icon(Icons.lightbulb_outline,
                    size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Gere sugestões personalizadas de consumo\ncom base nos itens da sua dispensa.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => ref
                      .read(suggestionsControllerProvider.notifier)
                      .generate(env.id),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Gerar sugestões'),
                ),
              ],
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MarkdownBody(data: suggestions),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _MessageBox({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _NoKeyMessage extends StatelessWidget {
  final VoidCallback onGoProfile;
  const _NoKeyMessage({required this.onGoProfile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Cadastre sua chave da API Google',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Para usar as sugestões inteligentes, você precisa cadastrar sua chave do Gemini na tela de Perfil.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onGoProfile,
              icon: const Icon(Icons.person_outline),
              label: const Text('Ir para o Perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
