import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import '../models/task.dart';
import 'api_client.dart';
import 'foco_repository.dart';
import 'local_repository.dart';

/// Sincroniza con el backend (MySQL) sin dejar de ser local-first: cada cambio
/// se guarda primero en una copia local de la cuenta y luego se envía. Si no
/// hay red, la copia local manda y se reenvía en cuanto se pueda.
class ApiRepository implements FocoRepository {
  final ApiClient api;
  final String userId;

  /// Se llama cuando el backend rechaza el token (sesión caducada).
  final VoidCallback? onUnauthorized;

  final LocalRepository _cache;
  final LocalRepository _sinCuenta;

  ApiRepository({
    required this.api,
    required this.userId,
    this.onUnauthorized,
    LocalRepository? sinCuenta,
  })  : _cache = LocalRepository(namespace: 'u:$userId:'),
        _sinCuenta = sinCuenta ?? LocalRepository();

  /// Las tareas del modo sin cuenta se suben una sola vez, a la primera
  /// cuenta que inicie sesión en este dispositivo.
  static const _importadoKey = 'foco_local_importado_v1';
  String get _pendienteKey => 'u:$userId:foco_sync_pendiente_v1';

  static const _reintento = Duration(seconds: 20);

  /// Último cuerpo pendiente por ruta: si hay varios cambios seguidos solo se
  /// envía el más reciente.
  final Map<String, Object> _cola = {};
  Future<void>? _enviando;
  Timer? _timerReintento;
  bool _cerrado = false;

  @override
  bool get esRemoto => true;

  @override
  void dispose() {
    _cerrado = true;
    _timerReintento?.cancel();
    _cola.clear();
  }

  @override
  Future<FocoSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (prefs.getBool(_pendienteKey) ?? false) {
        final local = await _cache.load();
        await _subir(local);
        await prefs.remove(_pendienteKey);
        return local;
      }

      var snap = snapshotFromWire(await api.get('/api/sync'));
      if (snap.tasks.isEmpty && !(prefs.getBool(_importadoKey) ?? false)) {
        snap = await _importarSinCuenta() ?? snap;
        await prefs.setBool(_importadoKey, true);
      }
      await _cache.saveAll(snap);
      return snap;
    } on ApiException catch (e) {
      if (e.noAutorizado) onUnauthorized?.call();
      return _cache.load();
    }
  }

  Future<FocoSnapshot?> _importarSinCuenta() async {
    final local = await _sinCuenta.load();
    if (local.tasks.isEmpty) return null;
    try {
      await _subir(local);
      return local;
    } on ApiException catch (e) {
      // 409: esas tareas ya se importaron en otra cuenta.
      if (e.status == 409) return null;
      rethrow;
    }
  }

  Future<void> _subir(FocoSnapshot snap) async {
    await api.put('/api/sync/tasks', _tasksBody(snap.tasks));
    await api.put('/api/sync/projects', _projectsBody(snap.projects));
    await api.put('/api/sync/achievements',
        {'achievements': snap.unlockedAchievements.toList()});
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    await _cache.saveTasks(tasks);
    await _encolar('/api/sync/tasks', _tasksBody(tasks));
  }

  @override
  Future<void> saveProjects(List<Project> projects) async {
    await _cache.saveProjects(projects);
    await _encolar('/api/sync/projects', _projectsBody(projects));
  }

  @override
  Future<void> saveUnlockedAchievements(Set<String> achievementIds) async {
    await _cache.saveUnlockedAchievements(achievementIds);
    await _encolar(
        '/api/sync/achievements', {'achievements': achievementIds.toList()});
  }

  Future<void> _encolar(String ruta, Object body) async {
    if (_cerrado) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendienteKey, true);
    _cola
      ..remove(ruta)
      ..[ruta] = body;
    _timerReintento?.cancel();
    return _enviando ??= _vaciar();
  }

  Future<void> _vaciar() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      while (_cola.isNotEmpty && !_cerrado) {
        final ruta = _cola.keys.first;
        final body = _cola.remove(ruta)!;
        try {
          await api.put(ruta, body);
        } on ApiException catch (e) {
          if (e.noAutorizado) {
            _cola.clear();
            onUnauthorized?.call();
            return;
          }
          if (e.esRed || e.status! >= 500) {
            _cola.putIfAbsent(ruta, () => body);
            _timerReintento?.cancel();
            _timerReintento = Timer(_reintento, () {
              if (!_cerrado && _cola.isNotEmpty) _enviando ??= _vaciar();
            });
            return;
          }
          // Un 4xx no se arregla reintentando; la copia local se conserva.
          debugPrint('Foco: el backend rechazó $ruta: ${e.mensaje}');
        }
      }
      if (!_cerrado) unawaited(prefs.remove(_pendienteKey));
    } finally {
      _enviando = null;
    }
  }

  // ---- Formato de la API ----

  static const _estadoWire = {
    TaskStatus.pendiente: 'pendiente',
    TaskStatus.enProgreso: 'en_progreso',
    TaskStatus.completada: 'completada',
  };

  static Map<String, dynamic> _tasksBody(List<Task> tasks) =>
      {'tasks': tasks.map(taskToWire).toList()};

  static Map<String, dynamic> _projectsBody(List<Project> projects) =>
      {'projects': projects.map(projectToWire).toList()};

  static String? _fecha(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseFecha(Object? v) {
    if (v is! String) return null;
    final p = v.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static DateTime? _parseInstante(Object? v) =>
      v is String ? DateTime.parse(v).toLocal() : null;

  static Map<String, dynamic> taskToWire(Task t) => {
        'id': t.id,
        'titulo': t.titulo,
        'descripcion': t.descripcion,
        'fechaLimite': _fecha(t.fechaLimite),
        'horasEstimadas': t.horasEstimadas,
        'estado': _estadoWire[t.estado],
        'categoria': t.categoria.name,
        'impacto': t.impacto,
        'urgencia': t.urgencia,
        'ansiedad': t.ansiedad,
        'activa': t.activa,
        'dependencias': t.dependencias,
        'completadaEn': t.completadaEn?.toUtc().toIso8601String(),
        'creada': t.creada.toUtc().toIso8601String(),
      };

  static Task taskFromWire(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        titulo: j['titulo'] as String,
        descripcion: (j['descripcion'] as String?) ?? '',
        fechaLimite: _parseFecha(j['fechaLimite']),
        horasEstimadas: (j['horasEstimadas'] as num?)?.toDouble() ?? 1,
        estado: _estadoWire.entries
            .firstWhere((e) => e.value == j['estado'],
                orElse: () =>
                    const MapEntry(TaskStatus.pendiente, 'pendiente'))
            .key,
        categoria: TaskCategory.values.firstWhere(
            (c) => c.name == j['categoria'],
            orElse: () => TaskCategory.proyecto),
        impacto: (j['impacto'] as num?)?.toInt() ?? 3,
        urgencia: (j['urgencia'] as num?)?.toInt() ?? 3,
        ansiedad: (j['ansiedad'] as num?)?.toInt() ?? 3,
        activa: (j['activa'] as bool?) ?? false,
        dependencias:
            (j['dependencias'] as List?)?.cast<String>().toList() ?? [],
        completadaEn: _parseInstante(j['completadaEn']),
        creada: _parseInstante(j['creada']),
      );

  static Map<String, dynamic> projectToWire(Project p) => {
        'id': p.id,
        'nombre': p.nombre,
        'fechaLimite': _fecha(p.fechaLimite),
        'estado': p.estado,
        'creada': p.creada.toUtc().toIso8601String(),
      };

  static Project projectFromWire(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        fechaLimite: _parseFecha(j['fechaLimite']),
        estado: (j['estado'] as String?) ?? 'activo',
        creada: _parseInstante(j['creada']),
      );

  static FocoSnapshot snapshotFromWire(Map<String, dynamic> j) => FocoSnapshot(
        tasks: ((j['tasks'] as List?) ?? const [])
            .map((e) => taskFromWire(e as Map<String, dynamic>))
            .toList(),
        projects: ((j['projects'] as List?) ?? const [])
            .map((e) => projectFromWire(e as Map<String, dynamic>))
            .toList(),
        unlockedAchievements:
            ((j['achievements'] as List?) ?? const []).cast<String>().toSet(),
      );
}
