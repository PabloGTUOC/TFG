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
          await client.send(req).timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('Request timed out — check your connection.');
    } on http.ClientException {
      // http wraps SocketException & co.; surface a human message instead
      // of "ClientException with SocketException: Failed host lookup…".
      throw ApiException('Network error — check your connection.');
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

  /// Multipart upload (avatar endpoints). Mirrors the Vue FormData calls:
  /// auth header only, no JSON content type.
  Future<dynamic> uploadFile(String path,
      {required String field,
      required List<int> bytes,
      required String filename}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase$path'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(field, bytes,
          filename: filename.isEmpty ? 'avatar.jpg' : filename));
    http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('Upload timed out');
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
          : 'Upload failed (${res.statusCode})';
      throw ApiException(msg);
    }
    return data;
  }

  Future<dynamic> get(String path) => request(path);
  Future<dynamic> post(String path, [Object? body]) =>
      request(path, method: 'POST', body: body ?? {});
  Future<dynamic> put(String path, Object? body) =>
      request(path, method: 'PUT', body: body);
  Future<dynamic> patch(String path, Object? body) =>
      request(path, method: 'PATCH', body: body);
  Future<dynamic> delete(String path, [Object? body]) =>
      request(path, method: 'DELETE', body: body);
}
