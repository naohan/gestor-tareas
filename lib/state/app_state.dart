import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/pet_state.dart';
import '../core/priority_engine.dart';
import '../data/foco_repository.dart';
import '../models/achievement.dart';
import '../models/project.dart';
import '../models/task.dart';

/// Estado central de la app. Mantiene las tareas y delega la persistencia en
/// un [FocoRepository] (local u remoto). Las vistas derivadas (priorización,
/// mascota, logros) se calculan aquí, nunca se almacenan.
class AppState extends ChangeNotifier {
  final FocoRepository _repo;
  final _uuid = const Uuid();

  AppState(this._repo);

  final List<Task> _tasks = [];
  final List<Project> _projects = [];

  /// Logros ya registrados (persistidos). Sirven para no recelebrar.
  final Set<String> _unlocked = {};

  bool _loaded = false;
  bool get loaded => _loaded;

  bool get sincronizaRemoto => _repo.esRemoto;

  List<Task> get tasks => List.unmodifiable(_tasks);
  List<Project> get projects => List.unmodifiable(_projects);

  List<Task> get activas =>
      _tasks.where((t) => t.activa && !t.completada).toList();

  List<PriorityScore> get enEspera {
    final orden = PriorityEngine.priorizar(_tasks);
    return orden.where((s) => !s.task.activa && !s.bloqueada).toList();
  }

  List<PriorityScore> get bloqueadas {
    final orden = PriorityEngine.priorizar(_tasks);
    return orden.where((s) => s.bloqueada).toList();
  }

  List<PriorityScore> get priorizadas => PriorityEngine.priorizar(_tasks);

  List<Task> get completadas => _tasks.where((t) => t.completada).toList()
    ..sort((a, b) =>
        (b.completadaEn ?? b.creada).compareTo(a.completadaEn ?? a.creada));

  bool get topeActivosAlcanzado =>
      activas.length >= PriorityEngine.maxObjetivosActivos;

  PriorityScore? get recomendacion => PriorityEngine.recomendacion(_tasks);

  PetState get pet => PetState.fromTasks(_tasks);

  /// Logros conseguidos alguna vez. Un logro ganado no se pierde aunque luego
  /// se borre o reabra la tarea que lo desbloqueó, o se corte una racha.
  List<Achievement> get logrosDesbloqueados {
    final ahora = Achievements.desbloqueados(_tasks).map((a) => a.id).toSet();
    return Achievements.all
        .where((a) => ahora.contains(a.id) || _unlocked.contains(a.id))
        .toList();
  }

  /// Logros recién conseguidos que aún no se han registrado/celebrado.
  List<Achievement> get logrosNuevos => Achievements.desbloqueados(_tasks)
      .where((a) => !_unlocked.contains(a.id))
      .toList();

  Future<void> marcarLogrosVistos() async {
    for (final a in logrosNuevos) {
      _unlocked.add(a.id);
    }
    notifyListeners();
    await _repo.saveUnlockedAchievements(Set.of(_unlocked));
  }

  // ---- Carga ----

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _repo.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final snap = await _repo.load();
    if (_disposed) return;
    _tasks
      ..clear()
      ..addAll(snap.tasks);
    _projects
      ..clear()
      ..addAll(snap.projects);
    _unlocked
      ..clear()
      ..addAll(snap.unlockedAchievements);
    _loaded = true;
    notifyListeners();
  }

  // ---- Operaciones sobre tareas ----

  Task addTask({
    required String titulo,
    String descripcion = '',
    DateTime? fechaLimite,
    double horasEstimadas = 1,
    TaskCategory categoria = TaskCategory.proyecto,
    int impacto = 3,
    int urgencia = 3,
    int ansiedad = 3,
    List<String> dependencias = const [],
  }) {
    final task = Task(
      id: _uuid.v4(),
      titulo: titulo,
      descripcion: descripcion,
      fechaLimite: fechaLimite,
      horasEstimadas: horasEstimadas,
      categoria: categoria,
      impacto: impacto,
      urgencia: urgencia,
      ansiedad: ansiedad,
      dependencias: List.of(dependencias),
    );
    _tasks.add(task);
    _persistTasks();
    notifyListeners();
    return task;
  }

  void updateTask(Task updated) {
    final i = _tasks.indexWhere((t) => t.id == updated.id);
    if (i == -1) return;
    _tasks[i] = updated;
    _persistTasks();
    notifyListeners();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    for (final t in _tasks) {
      t.dependencias.remove(id);
    }
    _persistTasks();
    notifyListeners();
  }

  void toggleCompletada(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    final t = _tasks[i];
    if (t.completada) {
      t.estado = TaskStatus.pendiente;
      t.completadaEn = null;
    } else {
      t.estado = TaskStatus.completada;
      t.completadaEn = DateTime.now();
      t.activa = false;
    }
    _persistTasks();
    notifyListeners();
  }

  bool toggleActiva(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return false;
    final t = _tasks[i];
    if (!t.activa && topeActivosAlcanzado) return false;
    t.activa = !t.activa;
    _persistTasks();
    notifyListeners();
    return true;
  }

  void _persistTasks() {
    // Fire-and-forget: la UI ya refleja el cambio en memoria.
    _repo.saveTasks(List.of(_tasks));
  }
}
