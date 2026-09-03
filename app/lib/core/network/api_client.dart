import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

class ApiClient {
  ApiClient._();

  static final _storage = FlutterSecureStorage(
    webOptions: const WebOptions(
      dbName: 'despensaviva_session',
      publicKey: 'despensaviva',
    ),
  );

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: AppConstants.storageTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final envId = await _storage.read(key: AppConstants.storageEnvKey);
          if (envId != null && envId.isNotEmpty) {
            options.headers['X-Environment-Id'] = envId;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.delete(key: AppConstants.storageTokenKey);
            await _storage.delete(key: AppConstants.storageUserKey);
          }
          handler.next(error);
        },
      ),
    );

  static Future<String?> getToken() =>
      _storage.read(key: AppConstants.storageTokenKey);

  static Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.storageTokenKey, value: token);

  static Future<String?> getActiveEnvironment() =>
      _storage.read(key: AppConstants.storageEnvKey);

  static Future<void> saveActiveEnvironment(String environmentId) =>
      _storage.write(key: AppConstants.storageEnvKey, value: environmentId);

  static Future<void> clearAuth() async {
    await _storage.delete(key: AppConstants.storageTokenKey);
    await _storage.delete(key: AppConstants.storageUserKey);
    await _storage.delete(key: AppConstants.storageEnvKey);
  }
}