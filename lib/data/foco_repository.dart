import '../models/project.dart';
import '../models/task.dart';

/// Snapshot completo de los datos de dominio de un usuario.
class FocoSnapshot {
  final List<Task> tasks;
  final List<Project> projects;
  final Set<String> unlockedAchievements;

  const FocoSnapshot({
    required this.tasks,
    required this.projects,
    required this.unlockedAchievements,
  });

  const FocoSnapshot.empty()
      : tasks = const [],
        projects = const [],
        unlockedAchievements = const {};
}

/// Contrato de persistencia de Foco. La app trabaja siempre contra esta
/// interfaz; da igual si detrás hay almacenamiento local o el backend.
///
/// El motor de prioridad y la mascota NO se persisten: son derivados.
abstract class FocoRepository {
  /// Carga inicial de todos los datos del usuario.
  Future<FocoSnapshot> load();

  Future<void> saveTasks(List<Task> tasks);

  Future<void> saveProjects(List<Project> projects);

  /// Registra el conjunto de logros desbloqueados (idempotente).
  Future<void> saveUnlockedAchievements(Set<String> achievementIds);

  /// ¿Este repositorio sincroniza con un backend remoto?
  bool get esRemoto;

  /// Deja de enviar cambios pendientes (al cerrar sesión o cambiar de cuenta).
  void dispose();
}
