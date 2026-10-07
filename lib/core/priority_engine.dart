import '../models/task.dart';

enum PriorityLevel { baja, media, alta, muyAlta }

extension PriorityLevelX on PriorityLevel {
  String get label {
    switch (this) {
      case PriorityLevel.baja:
        return 'Baja';
      case PriorityLevel.media:
        return 'Media';
      case PriorityLevel.alta:
        return 'Alta';
      case PriorityLevel.muyAlta:
        return 'Muy alta';
    }
  }

  String get mensaje {
    switch (this) {
      case PriorityLevel.baja:
        return 'Puede esperar sin culpa.';
      case PriorityLevel.media:
        return 'Avánzala cuando cierres lo urgente.';
      case PriorityLevel.alta:
        return 'Conviene hacerle hueco pronto.';
      case PriorityLevel.muyAlta:
        return 'Esta tarea merece tu atención hoy.';
    }
  }
}

/// Resultado del cálculo de prioridad para una tarea, con el desglose
/// para poder explicarle al usuario *por qué* algo es prioritario.
class PriorityScore {
  final Task task;
  final double total;
  final double base; // (urgencia + impacto) × 2
  final double presionFecha; // empuje por cercanía de la fecha límite
  final double penalizacionTiempo; // resta por mucho tiempo disponible
  final bool bloqueada; // depende de tareas sin completar

  const PriorityScore({
    required this.task,
    required this.total,
    required this.base,
    required this.presionFecha,
    required this.penalizacionTiempo,
    required this.bloqueada,
  });

  /// Frase corta que explica la recomendación.
  String get razon {
    if (bloqueada) return 'Depende de otra tarea sin terminar';
    if (task.vencida) return 'Ya venció: ciérrala o renegocia la fecha';
    final d = task.diasRestantes;
    if (d != null && d <= 1) return 'Vence en menos de 24 h';
    if (task.impacto >= 4 && task.urgencia >= 4) {
      return 'Alto impacto y muy urgente';
    }
    if (task.ansiedad >= 4) return 'Te está bloqueando: hazla y libera la mente';
    if (task.impacto >= 4) return 'Mucho impacto, mueve la aguja';
    if (d != null && d <= 3) return 'La fecha aprieta';
    return 'Avanza cuando termines lo de arriba';
  }

  PriorityLevel get nivel {
    if (total >= 18) return PriorityLevel.muyAlta;
    if (total >= 13) return PriorityLevel.alta;
    if (total >= 8) return PriorityLevel.media;
    return PriorityLevel.baja;
  }
}

/// El núcleo: la mayoría de las apps muestran TODO. Esta DECIDE qué mostrar.
///
/// Fórmula base (alineada con el diseño original), con ejes de 1 a 5:
///   Prioridad = (Urgencia + Impacto) × 2 + PresiónDeFecha - TiempoDisponible
///
/// La ansiedad no infla la prioridad por sí sola (si no, todo se sentiría
/// urgente), pero se usa como desempate: ante puntajes parecidos, primero
/// va lo que más te bloquea, para liberar la mente.
class PriorityEngine {
  /// Máximo de objetivos activos simultáneos. El cerebro se bloquea con 15
  /// cosas abiertas; aquí solo se permiten unos pocos focos a la vez.
  static const int maxObjetivosActivos = 3;

  static PriorityScore score(Task task) {
    final base = (task.urgencia + task.impacto) * 2.0;

    // Presión por fecha: cuanto menos falta, más empuja. Si ya venció, máximo.
    double presionFecha = 0;
    double penalizacionTiempo = 0;
    final dias = task.diasRestantes;
    if (dias != null) {
      if (dias < 0) {
        presionFecha = 12; // vencida: arriba del todo
      } else if (dias == 0) {
        presionFecha = 10;
      } else if (dias <= 2) {
        presionFecha = 8;
      } else if (dias <= 5) {
        presionFecha = 5;
      } else if (dias <= 10) {
        presionFecha = 3;
      } else {
        presionFecha = 1;
        // Mucho tiempo disponible => penaliza (puede esperar).
        penalizacionTiempo = (dias / 30).clamp(0, 4).toDouble();
      }
    }

    final total = base + presionFecha - penalizacionTiempo;

    return PriorityScore(
      task: task,
      total: total,
      base: base,
      presionFecha: presionFecha,
      penalizacionTiempo: penalizacionTiempo,
      bloqueada: false,
    );
  }

  /// Indica si una tarea está bloqueada porque alguna de sus dependencias
  /// todavía no está completada.
  static bool estaBloqueada(Task task, List<Task> todas) {
    if (task.dependencias.isEmpty) return false;
    for (final depId in task.dependencias) {
      final dep = todas.where((t) => t.id == depId);
      if (dep.isNotEmpty && !dep.first.completada) return true;
    }
    return false;
  }

  /// Ordena las tareas no completadas por prioridad descendente,
  /// dejando las bloqueadas al final. Devuelve los puntajes con desglose.
  static List<PriorityScore> priorizar(List<Task> tareas) {
    final pendientes = tareas.where((t) => !t.completada).toList();

    final scores = pendientes.map((t) {
      final s = score(t);
      final bloqueada = estaBloqueada(t, tareas);
      return PriorityScore(
        task: t,
        total: s.total,
        base: s.base,
        presionFecha: s.presionFecha,
        penalizacionTiempo: s.penalizacionTiempo,
        bloqueada: bloqueada,
      );
    }).toList();

    scores.sort((a, b) {
      // 1) No bloqueadas primero.
      if (a.bloqueada != b.bloqueada) return a.bloqueada ? 1 : -1;
      // 2) Mayor puntaje primero.
      final cmp = b.total.compareTo(a.total);
      if (cmp != 0) return cmp;
      // 3) Desempate: más ansiedad primero (libera el bloqueo mental).
      final cmpAns = b.task.ansiedad.compareTo(a.task.ansiedad);
      if (cmpAns != 0) return cmpAns;
      // 4) Menos horas estimadas primero (victoria rápida).
      return a.task.horasEstimadas.compareTo(b.task.horasEstimadas);
    });

    return scores;
  }

  /// La recomendación del día: la mejor tarea no bloqueada que hacer ahora.
  static PriorityScore? recomendacion(List<Task> tareas) {
    final orden = priorizar(tareas);
    for (final s in orden) {
      if (!s.bloqueada) return s;
    }
    return orden.isNotEmpty ? orden.first : null;
  }
}
