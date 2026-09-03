class AppConstants {
  AppConstants._();

  // URL base da API. Para emulador Android use http://10.0.2.2:3007/api
  static const String apiBaseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3007/api');

  static const String storageTokenKey = 'auth_token';
  static const String storageUserKey = 'auth_user';
  static const String storageEnvKey = 'active_environment';
}