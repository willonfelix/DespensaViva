import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/environment.dart';
import '../pantry/pantry_controller.dart';
import '../shopping/shopping_controller.dart';
import '../suggestions/suggestions_controller.dart';

class EnvironmentState {
  final List<Environment> environments;
  final String? activeEnvironmentId;
  final bool loading;
  final String? error;

  const EnvironmentState({
    this.environments = const [],
    this.activeEnvironmentId,
    this.loading = false,
    this.error,
  });

  EnvironmentState copyWith({
    List<Environment>? environments,
    String? activeEnvironmentId,
    bool? loading,
    String? error,
  }) =>
      EnvironmentState(
        environments: environments ?? this.environments,
        activeEnvironmentId: activeEnvironmentId ?? this.activeEnvironmentId,
        loading: loading ?? this.loading,
        error: error,
      );

  Environment? get activeEnvironment {
    if (activeEnvironmentId == null) return null;
    for (final e in environments) {
      if (e.id == activeEnvironmentId) return e;
    }
    return null;
  }

  bool get hasActiveEnvironment => activeEnvironment != null;
}

class EnvironmentController extends StateNotifier<EnvironmentState> {
  EnvironmentController() : super(const EnvironmentState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final response = await ApiClient.dio.get('/environments');
      final environments = (response.data['environments'] as List)
          .map((e) => Environment.fromJson(e as Map<String, dynamic>))
          .toList();

      final storedId = await ApiClient.getActiveEnvironment();
      String? active;
      if (storedId != null && environments.any((e) => e.id == storedId)) {
        active = storedId;
      } else if (environments.isNotEmpty) {
        active = environments.first.id;
      }
      if (active != null) await ApiClient.saveActiveEnvironment(active);

      state = EnvironmentState(
        environments: environments,
        activeEnvironmentId: active,
      );
    } on DioException catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Erro ao carregar ambientes.');
    }
  }

  Future<void> selectEnvironment(String environmentId) async {
    if (!state.environments.any((e) => e.id == environmentId)) return;
    await ApiClient.saveActiveEnvironment(environmentId);
    state = state.copyWith(activeEnvironmentId: environmentId);
  }

  Future<bool> create(String name) async {
    try {
      final response = await ApiClient.dio.post('/environments', data: {
        'name': name,
      });
      final env = Environment.fromJson(response.data['environment'] as Map<String, dynamic>);
      state = EnvironmentState(
        environments: [...state.environments, env],
        activeEnvironmentId: env.id,
      );
      await ApiClient.saveActiveEnvironment(env.id);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  Future<bool> rename(String id, String name) async {
    try {
      await ApiClient.dio.patch('/environments/$id', data: {'name': name});
      final environments = state.environments
          .map((e) => e.id == id ? Environment(id: e.id, name: name, myRole: e.myRole, memberCount: e.memberCount) : e)
          .toList();
      state = state.copyWith(environments: environments);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await ApiClient.dio.delete('/environments/$id');
      final environments =
          state.environments.where((e) => e.id != id).toList();
      String? active = state.activeEnvironmentId;
      if (active == id) {
        active = environments.isNotEmpty ? environments.first.id : null;
        if (active != null) await ApiClient.saveActiveEnvironment(active);
      }
      state = EnvironmentState(environments: environments, activeEnvironmentId: active);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  Future<Environment?> loadDetail(String id) async {
    try {
      final response = await ApiClient.dio.get('/environments/$id');
      final env = Environment.fromJson(response.data['environment'] as Map<String, dynamic>);
      final environments = state.environments
          .map((e) => e.id == id ? env : e)
          .toList();
      state = state.copyWith(environments: environments);
      return env;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return null;
    }
  }

  Future<bool> invite(String id, String email) async {
    try {
      final response = await ApiClient.dio.post('/environments/$id/members', data: {
        'email': email,
      });
      final members = (response.data['members'] as List)
          .map((e) => EnvironmentMember.fromJson(e as Map<String, dynamic>))
          .toList();
      _updateMembers(id, members);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  Future<bool> removeMember(String id, String userId) async {
    try {
      final response = await ApiClient.dio.delete('/environments/$id/members/$userId');
      final members = (response.data['members'] as List)
          .map((e) => EnvironmentMember.fromJson(e as Map<String, dynamic>))
          .toList();
      _updateMembers(id, members);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  Future<bool> changeRole(String id, String userId, String role) async {
    try {
      final response = await ApiClient.dio.put('/environments/$id/members/$userId', data: {
        'role': role,
      });
      final members = (response.data['members'] as List)
          .map((e) => EnvironmentMember.fromJson(e as Map<String, dynamic>))
          .toList();
      _updateMembers(id, members);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  void _updateMembers(String id, List<EnvironmentMember> members) {
    final environments = state.environments.map((e) {
      if (e.id != id) return e;
      return e.copyWith(members: members, memberCount: members.length);
    }).toList();
    state = state.copyWith(environments: environments);
  }

  String _message(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'] as String;
    return 'Erro ao processar ambiente.';
  }
}

final environmentControllerProvider =
    StateNotifierProvider<EnvironmentController, EnvironmentState>((ref) {
  return EnvironmentController();
});

// Watches env changes to reload pantry/shopping when the active environment changes.
final environmentWatcherProvider = Provider<void>((ref) {
  ref.listen<EnvironmentState>(environmentControllerProvider, (prev, next) {
    if (prev == null || prev.activeEnvironmentId != next.activeEnvironmentId) {
      if (next.activeEnvironmentId != null) {
        ref.read(pantryControllerProvider.notifier).load();
        ref.read(shoppingControllerProvider.notifier).load();
        ref
            .read(suggestionsControllerProvider.notifier)
            .loadEnvironment(next.activeEnvironmentId!);
      }
    }
  });
  return;
});
