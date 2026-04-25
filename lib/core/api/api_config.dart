class ApiConfig {
  // Use http://10.0.2.2:8000 for Android emulator
  // Use http://localhost:8000 for iOS simulator or web
  static const String baseUrl = 'http://localhost:8000';
  static const String socketUrl = baseUrl;

  static const String authEndpoint = '/api/auth';
  static const String passwordsEndpoint = '/api/passwords';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
