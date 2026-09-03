import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';

const _cacheTtl = Duration(hours: 6);
const _storage = FlutterSecureStorage(
  webOptions: WebOptions(
    dbName: 'despensaviva_session',
    publicKey: 'despensaviva',
  ),
);

String _cacheKey(String environmentId) => 'suggestions_$environmentId';

class SuggestionsState {
  final String? suggestions;
  final DateTime? generatedAt;
  final bool loading;
  final String? error;

  const SuggestionsState({
    this.suggestions,
    this.generatedAt,
    this.loading = false,
    this.error,
  });

  SuggestionsState copyWith({
    String? suggestions,
    DateTime? generatedAt,
    bool? loading,
    String? error,
  }) =>
      SuggestionsState(
        suggestions: suggestions ?? this.suggestions,
        generatedAt: generatedAt ?? this.generatedAt,
        loading: loading ?? this.loading,
        error: error,
      );
}

class SuggestionsController extends StateNotifier<SuggestionsState> {
  SuggestionsController() : super(const SuggestionsState());

  String? _currentEnvironment;

  // Restaura o cache salvo para o ambiente ativo ao abrir a aba
  Future<void> loadEnvironment(String environmentId) async {
    if (environmentId == _currentEnvironment && state.suggestions != null) {
      return;
    }
    _currentEnvironment = environmentId;
    try {
      final raw = await _storage.read(key: _cacheKey(environmentId));
      if (raw == null) {
        state = const SuggestionsState();
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['suggestions'] == null) {
        state = const SuggestionsState();
        return;
      }
      state = SuggestionsState(
        suggestions: map['suggestions'] as String,
        generatedAt: map['generated_at'] != null
            ? DateTime.tryParse(map['generated_at'] as String)
            : null,
      );
    } catch (_) {
      state = const SuggestionsState();
    }
  }

  Future<bool> generate(String environmentId) async {
    // Usa cache ainda válido
    if (state.suggestions != null &&
        state.generatedAt != null &&
        DateTime.now().difference(state.generatedAt!) < _cacheTtl) {
      return true;
    }

    state = state.copyWith(loading: true, error: null);
    try {
      final response = await ApiClient.dio.post('/suggestions/generate');
      final suggestions = response.data['suggestions'] as String;
      final generatedAt = DateTime.tryParse(
        response.data['generated_at'] as String? ?? '',
      );

      state = SuggestionsState(
        suggestions: suggestions,
        generatedAt: generatedAt ?? DateTime.now(),
      );
      _currentEnvironment = environmentId;

      await _storage.write(
        key: _cacheKey(environmentId),
        value: jsonEncode({
          'suggestions': suggestions,
          'generated_at': (generatedAt ?? DateTime.now()).toIso8601String(),
        }),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro ao gerar sugestões.');
      return false;
    }
  }

  Future<void> forceRefresh(String environmentId) async {
    // Pula o cache salvando um timestamp antigo antes de gerar
    await _storage.delete(key: _cacheKey(environmentId));
    state = SuggestionsState(
      suggestions: state.suggestions,
      generatedAt: DateTime.now().subtract(_cacheTtl),
      loading: state.loading,
      error: state.error,
    );
    await generate(environmentId);
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Não foi possível gerar sugestões.';
  }
}

final suggestionsControllerProvider =
    StateNotifierProvider<SuggestionsController, SuggestionsState>((ref) {
  return SuggestionsController();
});
