import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, {this.status = 0});

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Klien HTTP tipis. Semua respons server berbentuk:
/// { "success": true, "message": "...", "data": { ... } }
class ApiClient {
  String? token;
  final http.Client _http = http.Client();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send(
        () => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})),
      );

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiException('Koneksi lambat. Coba lagi sebentar.');
    } catch (_) {
      throw const ApiException('Tidak bisa terhubung ke server. Periksa internet Anda.');
    }

    dynamic json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw ApiException('Respons server tidak valid (${res.statusCode}).', status: res.statusCode);
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300 && !(json is Map && json['success'] == false);
    if (!ok) {
      final msg = json is Map && json['message'] != null ? '${json['message']}' : 'Terjadi kesalahan (${res.statusCode}).';
      throw ApiException(msg, status: res.statusCode);
    }
    return json is Map && json.containsKey('data') ? json['data'] : json;
  }
}
