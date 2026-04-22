import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_config.dart';
import 'models/api_models.dart';

class ApiService {
  late final Dio _dio;
  Dio get dio => _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'auth_token';
  static const String _masterPasswordKey = 'master_password';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _passwordKey = 'saved_password'; // For auto-fill

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        if (options.path.contains('/passwords')) {
          final masterPassword = await getMasterPassword();
          if (masterPassword != null) {
            options.headers['X-Master-Password'] = masterPassword;
          }
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await clearAuth();
        }
        return handler.next(error);
      },
    ));
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> saveMasterPassword(String masterPassword) async {
    await _storage.write(key: _masterPasswordKey, value: masterPassword);
  }

  Future<String?> getMasterPassword() async {
    return await _storage.read(key: _masterPasswordKey);
  }

  Future<void> saveUsername(String username) async {
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  /// Reads `user_id` from the JWT payload (no signature verification).
  Future<String?> getCurrentUserId() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      final mod = payload.length % 4;
      if (mod != 0) {
        payload += '=' * (4 - mod);
      }
      final jsonStr = utf8.decode(base64Url.decode(payload));
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return map['user_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveEmail(String email) async {
    await _storage.write(key: _emailKey, value: email);
  }

  Future<String?> getEmail() async {
    return await _storage.read(key: _emailKey);
  }

  Future<void> savePassword(String password) async {
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<String?> getPassword() async {
    return await _storage.read(key: _passwordKey);
  }

  Future<void> clearAuth() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _masterPasswordKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  /// Clears auth token but keeps username and password for auto-fill
  Future<void> clearAuthKeepCredentials() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _masterPasswordKey);
  }

  /// Check if user has saved credentials
  Future<bool> hasSavedCredentials() async {
    final username = await getUsername();
    final password = await getPassword();
    return username != null &&
        password != null &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }

  Future<TokenResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.authEndpoint}/register',
        data: request.toJson(),
      );
      return TokenResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<TokenResponse> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.authEndpoint}/login',
        data: FormData.fromMap({
          'username': username,
          'password': password,
        }),
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final tokenResponse = TokenResponse.fromJson(response.data);
      await saveToken(tokenResponse.accessToken);
      return tokenResponse;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<PasswordDto> createPassword(PasswordDto password) async {
    try {
      final response = await _dio.post(
        ApiConfig.passwordsEndpoint,
        data: password.toJson(),
      );
      return PasswordDto.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<PasswordDto> updatePassword(String id, PasswordDto password) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.passwordsEndpoint}/$id',
        data: password.toJson(),
      );
      return PasswordDto.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<PasswordListResponse> getPasswords({
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) queryParams['category'] = category;
      if (search != null) queryParams['search'] = search;

      final response = await _dio.get(
        ApiConfig.passwordsEndpoint,
        queryParameters: queryParams,
      );
      return PasswordListResponse.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deletePassword(String id) async {
    try {
      await _dio.delete('${ApiConfig.passwordsEndpoint}/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final data = error.response!.data;
        if (data is Map && data.containsKey('detail')) {
          return data['detail'].toString();
        }
        return 'Server error: ${error.response!.statusCode}';
      }
      return 'Network error: ${error.message}';
    }
    return error.toString();
  }
}
