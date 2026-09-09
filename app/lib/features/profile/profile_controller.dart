import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/audit_entry.dart';
import '../../models/user.dart';
import '../auth/auth_controller.dart';
import '../pantry/pantry_controller.dart';

class ProfileState {
  final bool loading;
  final String? error;
  final String? success;
  final List<AuditEntry> logs;
  final bool loadingAudit;

  const ProfileState({
    this.loading = false,
    this.error,
    this.success,
    this.logs = const [],
    this.loadingAudit = false,
  });

  ProfileState copyWith({
    bool? loading,
    String? error,
    String? success,
    List<AuditEntry>? logs,
    bool? loadingAudit,
  }) =>
      ProfileState(
        loading: loading ?? this.loading,
        error: error ?? this.error,
        success: success ?? this.success,
        logs: logs ?? this.logs,
        loadingAudit: loadingAudit ?? this.loadingAudit,
      );
}

class ProfileController extends StateNotifier<ProfileState> {
  final Ref _ref;
  ProfileController(this._ref) : super(const ProfileState());

  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(loading: true, error: null, success: null);
    try {
      await ApiClient.dio.put('/profile/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      state = state.copyWith(loading: false, success: 'Senha atualizada com sucesso.');
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro inesperado.');
      return false;
    }
  }

  Future<bool> saveGeminiKey(String key) async {
    state = state.copyWith(loading: true, error: null, success: null);
    try {
      final response = await ApiClient.dio.put('/profile/gemini-key', data: {
        'gemini_key': key,
      });
      _updateAuthHasKey(response.data['has_gemini_key'] == true);
      state = state.copyWith(
        loading: false,
        success: key.trim().isEmpty ? 'Chave removida.' : 'Chave salva com sucesso.',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro inesperado.');
      return false;
    }
  }

  void clearFeedback() => state = ProfileState(logs: state.logs);

  Future<bool> confirmPending() async {
    state = state.copyWith(loading: true, error: null, success: null);
    final ok = await _ref.read(pantryControllerProvider.notifier).confirmPending();
    state = state.copyWith(
      loading: false,
      success: ok ? 'Alterações da dispensa confirmadas.' : null,
      error: ok ? null : (state.error ?? 'Erro ao confirmar alterações.'),
    );
    if (ok) await loadAudit();
    return ok;
  }

  Future<void> loadAudit() async {
    state = state.copyWith(loadingAudit: true, error: null);
    try {
      final response = await ApiClient.dio.get('/audit');
      final logs = (response.data['logs'] as List)
          .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(loadingAudit: false, logs: logs);
    } on DioException catch (e) {
      state = state.copyWith(loadingAudit: false, error: _message(e), logs: const []);
    } catch (_) {
      state = state.copyWith(loadingAudit: false, error: 'Erro ao carregar histórico.', logs: const []);
    }
  }

  void _updateAuthHasKey(bool value) {
    final auth = _ref.read(authControllerProvider);
    final user = auth.user;
    if (user == null) return;
    final updated = User(
      id: user.id,
      email: user.email,
      name: user.name,
      hasGeminiKey: value,
    );
    _ref.read(authControllerProvider.notifier).updateUser(updated);
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Erro ao atualizar perfil.';
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  return ProfileController(ref);
});
