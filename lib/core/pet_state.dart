import '../models/task.dart';

/// Estados de ánimo de la mascota. No es un Tamagotchi: es un reflejo de tu
/// estado real según la carga, lo vencido y los cierres recientes.
enum PetMood { motivada, tranquila, enfocada, saturada, abrumada }

extension PetMoodX on PetMood {
  String get emoji {
    switch (this) {
      case PetMood.motivada:
        return '🎉';
      case PetMood.tranquila:
        return '😊';
      case PetMood.enfocada:
        return '🧘';
      case PetMood.saturada:
        return '😰';
      case PetMood.abrumada:
        return '😵‍💫';
    }
  }

  String get titulo {
    switch (this) {
      case PetMood.motivada:
        return 'Motivada';
      case PetMood.tranquila:
        return 'Tranquila';
      case PetMood.enfocada:
        return 'Enfocada';
      case PetMood.saturada:
        return 'Saturada';
      case PetMood.abrumada:
        return 'Abrumada';
    }
  }
}

class PetState {
  final PetMood mood;
  final String mensaje;

  const PetState(this.mood, this.mensaje);

  /// Deriva el estado emocional a partir de las tareas.
  factory PetState.fromTasks(List<Task> tareas) {
    final abiertas = tareas.where((t) => !t.completada).toList();
    final vencidas = abiertas.where((t) => t.vencida).length;
    final activas = abiertas.where((t) => t.activa).length;

    // ¿Cerró algo hoy? -> momento de celebrar.
    final hoy = DateTime.now();
    final cerradasHoy = tareas.where((t) {
      final c = t.completadaEn;
      return c != null &&
          c.year == hoy.year &&
          c.month == hoy.month &&
          c.day == hoy.day;
    }).length;

    if (cerradasHoy > 0 && vencidas == 0) {
      return PetState(
        PetMood.motivada,
        cerradasHoy == 1
            ? 'Cerraste algo hoy. Ese es el camino.'
            : 'Cerraste $cerradasHoy hoy. Vas con todo.',
      );
    }

    if (abiertas.length >= 12 || vencidas >= 4) {
      return const PetState(
        PetMood.abrumada,
        'Demasiado abierto. Elige solo 3 focos y suelta el resto por ahora.',
      );
    }

    if (abiertas.length >= 7 || vencidas >= 2) {
      return const PetState(
        PetMood.saturada,
        'Se está acumulando. ¿Qué puedes cerrar o posponer hoy?',
      );
    }

    if (activas > 0 && activas <= PetState.maxFocos) {
      return PetState(
        PetMood.enfocada,
        'Tienes $activas foco(s) activo(s). Ve uno a la vez.',
      );
    }

    return const PetState(
      PetMood.tranquila,
      'Todo bajo control. Buen momento para avanzar sin prisa.',
    );
  }

  static const int maxFocos = 3;
}
