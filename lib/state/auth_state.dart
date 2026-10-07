import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/api_client.dart';
import '../models/foco_user.dart';

enum AuthStatus {
  /// Leyendo la sesión guardada.
  cargando,

  /// Hay backend pero no hay sesión: se muestra login/registro.
  sinSesion,

  /// Sesión iniciada: los datos se sincronizan con el backend.
  conSesion,

  /// Sin cuenta: los datos viven solo en este dispositivo.
  local,
}

/// Sesión del usuario. El JWT se guarda en el dispositivo y se envía en cada
/// petición; si el backend lo rechaza (401) la sesión se cierra.
class AuthState extends ChangeNotifier {
  static const _sesionKey = 'foco_auth_v1';
  static const _modoLocalKey = 'foco_modo_local_v1';

  final ApiClient? api;

  AuthState({ApiClient? api})
      : api = api ?? (AppConfig.usaApi ? ApiClient(AppConfig.apiUrl) : null);

  AuthStatus _status = AuthStatus.cargando;
  AuthStatus get status => _status;

  FocoUser? _user;
  FocoUser? get user => _user;

  /// Mensaje para mostrar en la pantalla de acceso (p. ej. sesión caducada).
  String? aviso;

  bool get hayBackend => api != null;

  Future<void> init() async {
    final api = this.api;
    if (api == null) {
      _cambiar(AuthStatus.local);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sesionKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        api.token = json['token'] as String;
        _user = FocoUser.fromJson(json['user'] as Map<String, dynamic>);
        _cambiar(AuthStatus.conSesion);
        _refrescarPerfil();
        return;
      } catch (_) {
        await prefs.remove(_sesionKey);
      }
    }
    _cambiar(prefs.getBool(_modoLocalKey) ?? false
        ? AuthStatus.local
        : AuthStatus.sinSesion);
  }

  Future<void> login({required String email, required String password}) async {
    final data = await api!.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    await _guardarSesion(data);
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final data = await api!.post('/api/auth/register', {
      'nombre': nombre.trim(),
      'email': email.trim(),
      'password': password,
    });
    await _guardarSesion(data);
  }

  Future<void> continuarSinCuenta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_modoLocalKey, true);
    _cambiar(AuthStatus.local);
  }

  /// Desde el modo sin cuenta, vuelve a la pantalla de acceso.
  Future<void> irAIniciarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modoLocalKey);
    aviso = null;
    _cambiar(AuthStatus.sinSesion);
  }

  Future<void> cerrarSesion({bool caducada = false}) async {
    if (_status != AuthStatus.conSesion) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sesionKey);
    await prefs.remove(_modoLocalKey);
    api?.token = null;
    _user = null;
    aviso = caducada ? 'Tu sesión caducó. Vuelve a iniciar sesión.' : null;
    _cambiar(AuthStatus.sinSesion);
  }

  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = FocoUser.fromJson(data['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _sesionKey, jsonEncode({'token': token, 'user': user.toJson()}));
    await prefs.remove(_modoLocalKey);
    api!.token = token;
    _user = user;
    aviso = null;
    _cambiar(AuthStatus.conSesion);
  }

  /// Actualiza nombre/email desde el backend. Sin red se mantiene la sesión
  /// guardada (la app sigue funcionando con la copia local).
  Future<void> _refrescarPerfil() async {
    try {
      final data = await api!.get('/api/auth/me');
      final user = FocoUser.fromJson(data['user'] as Map<String, dynamic>);
      if (_status != AuthStatus.conSesion || user.id != _user?.id) return;
      _user = user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sesionKey,
          jsonEncode({'token': api!.token, 'user': user.toJson()}));
      notifyListeners();
    } on ApiException catch (e) {
      if (e.noAutorizado) await cerrarSesion(caducada: true);
    }
  }

  void _cambiar(AuthStatus s) {
    _status = s;
    notifyListeners();
  }
}
