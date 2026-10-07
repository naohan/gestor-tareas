import '../models/task.dart';

/// Logro. La filosofía: no premiar CANTIDAD, premiar CIERRE.
/// Terminar proyectos, entregar antes de tiempo y sostener el enfoque.
class Achievement {
  final String id;
  final String titulo;
  final String descripcion;
  final String emoji;

  /// Evalúa si el logro está desbloqueado según el estado de las tareas.
  final bool Function(List<Task> tareas) condicion;

  const Achievement({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.emoji,
    required this.condicion,
  });
}

/// Catálogo de logros disponibles.
class Achievements {
  static int _completadas(List<Task> t) =>
      t.where((x) => x.completada).length;

  /// Días consecutivos (incluyendo hoy hacia atrás) en los que se cerró
  /// al menos una tarea.
  static int _rachaEnfoque(List<Task> tareas) {
    final dias = tareas
        .where((t) => t.completada && t.completadaEn != null)
        .map((t) => DateTime(t.completadaEn!.year, t.completadaEn!.month,
            t.completadaEn!.day))
        .toSet();
    if (dias.isEmpty) return 0;

    final ahora = DateTime.now();
    var cursor = DateTime(ahora.year, ahora.month, ahora.day);
    // Si hoy no se cerró nada, la racha puede seguir contando desde ayer.
    if (!dias.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!dias.contains(cursor)) return 0;
    }
    var racha = 0;
    while (dias.contains(cursor)) {
      racha++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return racha;
  }

  static final List<Achievement> all = [
    Achievement(
      id: 'primer_cierre',
      titulo: 'Primer cierre',
      descripcion: 'Completaste tu primera tarea.',
      emoji: '✅',
      condicion: (t) => _completadas(t) >= 1,
    ),
    Achievement(
      id: 'primer_proyecto',
      titulo: 'Primer proyecto terminado',
      descripcion: 'Cerraste una tarea de categoría Proyecto.',
      emoji: '🏆',
      condicion: (t) => t.any(
          (x) => x.completada && x.categoria == TaskCategory.proyecto),
    ),
    Achievement(
      id: 'antes_de_fecha',
      titulo: 'Entrega anticipada',
      descripcion: 'Terminaste algo antes de su fecha límite.',
      emoji: '⏱️',
      condicion: (t) => t.any((x) =>
          x.completada &&
          x.fechaLimite != null &&
          x.completadaEn != null &&
          x.completadaEn!.isBefore(x.fechaLimite!)),
    ),
    Achievement(
      id: 'enfoque_3_dias',
      titulo: '3 días de enfoque',
      descripcion: 'Cerraste algo 3 días seguidos.',
      emoji: '🔥',
      condicion: (t) => _rachaEnfoque(t) >= 3,
    ),
    Achievement(
      id: 'mente_despejada',
      titulo: 'Mente despejada',
      descripcion: 'Cerraste una tarea con ansiedad alta (≥ 4).',
      emoji: '🧠',
      condicion: (t) =>
          t.any((x) => x.completada && x.ansiedad >= 4),
    ),
    Achievement(
      id: 'cinco_cierres',
      titulo: 'Cinco cerradas',
      descripcion: 'Completaste 5 tareas en total.',
      emoji: '🌟',
      condicion: (t) => _completadas(t) >= 5,
    ),
  ];

  static List<Achievement> desbloqueados(List<Task> tareas) =>
      all.where((a) => a.condicion(tareas)).toList();
}
