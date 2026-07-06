import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Thin REST client mirroring stores/auth.js `request()` in the Vue app:
/// JSON in/out, Bearer token, 10s timeout, error message from `data.error`.
class ApiClient {
  /// Override at build time: flutter run --dart-define=API_BASE=http://192.168.1.10:3000
  /// (Android emulators reach the host machine via http://10.0.2.2:3000.)
  static const String apiBase =
      String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3000');

  String token = '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> request(String path,
      {String method = 'GET', Object? body}) async {
    final uri = Uri.parse('$apiBase$path');
    final client = http.Client();
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed =
          await client.send(req).timeout(const Duration(seconds: 10));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('Request timed out');
    } finally {
      client.close();
    }

    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = <String, dynamic>{};
    }
    if (res.statusCode >= 400) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Request failed (${res.statusCode})';
      throw ApiException(msg);
    }
    return data;
  }

  Future<dynamic> get(String path) => request(path);
  Future<dynamic> post(String path, [Object? body]) =>
      request(path, method: 'POST', body: body ?? {});
  Future<dynamic> put(String path, Object? body) =>
      request(path, method: 'PUT', body: body);
  Future<dynamic> delete(String path) => request(path, method: 'DELETE');
}
