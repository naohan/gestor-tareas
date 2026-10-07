import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error devuelto por la API (o de red, cuando [status] es null).
class ApiException implements Exception {
  final int? status;
  final String mensaje;

  const ApiException(this.status, this.mensaje);

  const ApiException.red()
      : status = null,
        mensaje = 'No se pudo conectar con el servidor. Revisa tu conexión.';

  bool get esRed => status == null;
  bool get noAutorizado => status == 401;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP mínimo para el backend de Foco. Envía el JWT como
/// `Authorization: Bearer` cuando hay sesión.
class ApiClient {
  final String baseUrl;
  final http.Client _http;
  String? token;

  static const _timeout = Duration(seconds: 15);

  ApiClient(String baseUrl, {http.Client? client})
      : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _http = client ?? http.Client();

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, Object body) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> put(String path, Object body) =>
      _send('PUT', path, body);

  Future<Map<String, dynamic>> delete(String path, [Object? body]) =>
      _send('DELETE', path, body);

  Future<Map<String, dynamic>> _send(String method, String path,
      [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException.red();
    } on http.ClientException {
      throw const ApiException.red();
    }

    Object? data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } on FormatException {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }
    throw ApiException(res.statusCode, _mensajeError(res.statusCode, data));
  }

  static String _mensajeError(int status, Object? data) {
    if (data is Map<String, dynamic>) {
      final detalles = data['detalles'];
      if (detalles is List && detalles.isNotEmpty) {
        final primero = detalles.first;
        if (primero is String) {
          // Formato del backend: "campo: mensaje".
          final i = primero.indexOf(': ');
          return i == -1 ? primero : primero.substring(i + 2);
        }
      }
      if (data['error'] is String) return data['error'] as String;
    }
    if (status == 429) return 'Demasiados intentos. Espera unos minutos.';
    if (status >= 500) return 'El servidor tuvo un problema. Inténtalo de nuevo.';
    return 'Error inesperado ($status).';
  }
}
