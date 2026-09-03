import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../models/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState());

  Future<void> loadSession() async {
    final token = await ApiClient.getToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final response = await ApiClient.dio.get('/auth/me');
      final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState(status: AuthStatus.unknown, error: null);
    try {
      final response = await ApiClient.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final token = response.data['token'] as String;
      final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
      await ApiClient.saveToken(token);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on DioException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        error: _errorMessage(e),
      );
      return false;
    } catch (_) {
      state = const AuthState(status: AuthStatus.error, error: 'Erro inesperado.');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = AuthState(status: AuthStatus.unknown, error: null);
    try {
      final response = await ApiClient.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      final token = response.data['token'] as String;
      final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
      await ApiClient.saveToken(token);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on DioException catch (e) {
      state = AuthState(status: AuthStatus.error, error: _errorMessage(e));
      return false;
    } catch (_) {
      state = const AuthState(status: AuthStatus.error, error: 'Erro inesperado.');
      return false;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearAuth();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'] as String;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Não foi possível conectar ao servidor.';
    }
    return 'Falha na autenticação.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});