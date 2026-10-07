import '../config/app_config.dart';
import '../models/calendar_event.dart';
import '../models/planner_models.dart';
import '../models/task.dart';
import 'priority_engine.dart';

/// Coloca los focos activos en la agenda. Lógica pura (sin red ni estado):
/// recibe ocupaciones y devuelve bloques planificados, para poder testearla.
///
/// No usa IA: combina el orden del motor de prioridad con los huecos libres.
class BlockPlanner {
  /// Calcula los huecos libres dentro de la jornada laboral, para [dias]
  /// días a partir de [desde], restando las ocupaciones [ocupados].
  static List<FreeSlot> huecosLibres({
    required DateTime desde,
    required int dias,
    required List<CalendarEvent> ocupados,
    int horaInicio = AppConfig.horaInicioJornada,
    int horaFin = AppConfig.horaFinJornada,
  }) {
    final libres = <FreeSlot>[];
    final inicioBase = DateTime(desde.year, desde.month, desde.day);

    for (var d = 0; d < dias; d++) {
      final dia = inicioBase.add(Duration(days: d));
      var jornadaIni = DateTime(dia.year, dia.month, dia.day, horaInicio);
      final jornadaFin = DateTime(dia.year, dia.month, dia.day, horaFin);

      // El primer día no se puede planificar en el pasado.
      if (jornadaIni.isBefore(desde)) {
        final ahora = _siguienteCuarto(desde);
        jornadaIni = ahora.isBefore(jornadaFin) ? ahora : jornadaFin;
      }
      if (!jornadaIni.isBefore(jornadaFin)) continue;

      // Ocupaciones que solapan con la jornada, ordenadas.
      final delDia = ocupados
          .where((e) =>
              e.ocupado &&
              e.fin.isAfter(jornadaIni) &&
              e.inicio.isBefore(jornadaFin))
          .toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

      var cursor = jornadaIni;
      for (final ev in delDia) {
        final ini = ev.inicio.isBefore(cursor) ? cursor : ev.inicio;
        if (ini.isAfter(cursor)) {
          libres.add(FreeSlot(cursor, ini));
        }
        if (ev.fin.isAfter(cursor)) cursor = ev.fin;
        if (!cursor.isBefore(jornadaFin)) break;
      }
      if (cursor.isBefore(jornadaFin)) {
        libres.add(FreeSlot(cursor, jornadaFin));
      }
    }
    return libres;
  }

  static DateTime _siguienteCuarto(DateTime t) {
    final base = DateTime(t.year, t.month, t.day, t.hour);
    final minutos = ((t.minute + (t.second > 0 ? 1 : 0)) / 15).ceil() * 15;
    return base.add(Duration(minutes: minutos));
  }

  /// Asigna las [tareasActivas] (en orden de prioridad) a los [huecos],
  /// troceando en bloques de como máximo [maxMinutosPorBloque] con descansos.
  static List<PlannedBlock> planificar({
    required List<Task> tareasActivas,
    required List<FreeSlot> huecos,
    int maxMinutosBloque = AppConfig.maxMinutosPorBloque,
    int minutosDescanso = AppConfig.minutosDescanso,
    int minMinutosBloque = AppConfig.minMinutosPorBloque,
  }) {
    // Orden de prioridad para las activas.
    final orden = PriorityEngine.priorizar(tareasActivas)
        .where((s) => !s.bloqueada)
        .map((s) => s.task)
        .toList();

    // Minutos restantes por tarea según su estimación.
    final restante = <String, double>{
      for (final t in orden) t.id: (t.horasEstimadas * 60),
    };

    // Copia mutable de huecos (cursor por hueco).
    final colaHuecos = List<FreeSlot>.from(huecos);
    final bloques = <PlannedBlock>[];

    for (final task in orden) {
      var minutosTarea = restante[task.id] ?? 0;
      var tieneBloques = false;

      while (minutosTarea > 0 && colaHuecos.isNotEmpty) {
        // Un resto pequeño cabe en el margen de error de la estimación.
        if (tieneBloques && minutosTarea < minMinutosBloque) break;

        final hueco = colaHuecos.first;
        final dispMin = hueco.duracion.inMinutes;
        if (dispMin < minMinutosBloque) {
          colaHuecos.removeAt(0);
          continue;
        }

        final minBloque = [
          minutosTarea,
          maxMinutosBloque.toDouble(),
          dispMin.toDouble(),
        ].reduce((a, b) => a < b ? a : b);

        final inicio = hueco.inicio;
        final fin = inicio.add(Duration(minutes: minBloque.round()));
        bloques.add(PlannedBlock(task: task, inicio: inicio, fin: fin));
        minutosTarea -= minBloque;
        tieneBloques = true;

        // Avanza el hueco añadiendo el descanso.
        final siguiente = fin.add(Duration(minutes: minutosDescanso));
        if (siguiente.isBefore(hueco.fin)) {
          colaHuecos[0] = hueco.copyWith(inicio: siguiente);
        } else {
          colaHuecos.removeAt(0);
        }
      }
      if (colaHuecos.isEmpty) break;
    }

    return bloques;
  }

  /// Convierte los bloques planificados en eventos `foco_planned` listos para
  /// escribirse en el calendario.
  static List<CalendarEvent> bloquesAEventos(
    List<PlannedBlock> bloques, {
    required String Function() nuevoId,
  }) {
    return bloques
        .map((b) => CalendarEvent(
              id: nuevoId(),
              taskId: b.task.id,
              titulo: 'Enfoque: ${b.task.titulo}',
              inicio: b.inicio,
              fin: b.fin,
              source: EventSource.focoPlanned,
              ocupado: true,
            ))
        .toList();
  }
}
